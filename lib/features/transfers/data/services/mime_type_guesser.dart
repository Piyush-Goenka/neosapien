class MimeTypeGuesser {
  const MimeTypeGuesser._();

  static String fromFileName(String fileName) {
    final trimmed = fileName.trim();
    final extensionIndex = trimmed.lastIndexOf('.');
    if (extensionIndex < 0 || extensionIndex == trimmed.length - 1) {
      return 'application/octet-stream';
    }

    final extension = trimmed.substring(extensionIndex + 1).toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'aac' => 'audio/aac',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'json' => 'application/json',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }
}
