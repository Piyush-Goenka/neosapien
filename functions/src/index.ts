import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

admin.initializeApp();

interface TransferFileData {
  id?: string;
  name?: string;
  byteCount?: number;
}

interface TransferDocumentData {
  senderUid?: string;
  senderCode?: string;
  recipientUid?: string;
  recipientCode?: string;
  status?: string;
  totalBytes?: number;
  files?: TransferFileData[];
}

interface PrivateFcmDocument {
  tokens?: string[];
}

export const onTransferCreated = onDocumentCreated(
  {
    document: 'transfers/{batchId}',
    region: 'us-central1',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn('onTransferCreated fired without snapshot.');
      return;
    }

    const data = snapshot.data() as TransferDocumentData;
    const batchId = event.params.batchId;
    const recipientUid = data.recipientUid;

    if (!recipientUid) {
      logger.warn(`Transfer ${batchId} has no recipientUid; skipping push.`);
      return;
    }

    const fileCount = (data.files ?? []).length;
    const totalBytes = data.totalBytes ?? 0;
    const senderCode = data.senderCode ?? '';

    const tokensRef = admin
      .firestore()
      .doc(`users/${recipientUid}/private/fcm`);

    const tokensSnap = await tokensRef.get();
    const tokensData = (tokensSnap.data() ?? {}) as PrivateFcmDocument;
    const tokens = (tokensData.tokens ?? []).filter(
      (value): value is string => typeof value === 'string' && value.length > 0,
    );

    if (tokens.length === 0) {
      logger.info(
        `Recipient ${recipientUid} has no FCM tokens; skipping push for ${batchId}.`,
      );
      return;
    }

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      data: {
        type: 'incoming_transfer',
        batchId,
        senderCode,
        fileCount: String(fileCount),
        totalBytes: String(totalBytes),
      },
      notification: {
        title: 'Incoming file transfer',
        body:
          fileCount === 1
            ? `${senderCode || 'Someone'} wants to send you a file.`
            : `${senderCode || 'Someone'} wants to send you ${fileCount} files.`,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'incoming_transfers',
          tag: batchId,
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            'mutable-content': 1,
            'thread-id': batchId,
          },
        },
      },
    });

    const invalidTokens: string[] = [];
    response.responses.forEach((resp, index) => {
      if (resp.success) {
        return;
      }
      const code = resp.error?.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(tokens[index]);
      } else {
        logger.warn(
          `FCM send to token failed for ${recipientUid} / ${batchId}: ${code}`,
        );
      }
    });

    if (invalidTokens.length > 0) {
      await tokensRef.update({
        tokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
      logger.info(
        `Removed ${invalidTokens.length} invalid FCM tokens from ${recipientUid}.`,
      );
    }

    logger.info(
      `FCM fan-out for ${batchId}: ${response.successCount} ok, ` +
        `${response.failureCount} failed, ${invalidTokens.length} pruned.`,
    );
  },
);
