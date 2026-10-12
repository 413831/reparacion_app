enum ChatMessageType {
  text,
  location,
  system,
  image,
}

class ChatMessage {
  final String id;
  final String jobId;
  final String senderId;
  final String senderName;
  final ChatMessageType type;
  final String content;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final bool isMine;

  ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.latitude,
    this.longitude,
    this.address,
    this.notes,
    required this.createdAt,
    required this.isMine,
  });

  factory ChatMessage.text({
    required String id,
    required String jobId,
    required String senderId,
    required String senderName,
    required String content,
    required bool isMine,
  }) {
    return ChatMessage(
      id: id,
      jobId: jobId,
      senderId: senderId,
      senderName: senderName,
      type: ChatMessageType.text,
      content: content,
      createdAt: DateTime.now(),
      isMine: isMine,
    );
  }

  factory ChatMessage.location({
    required String id,
    required String jobId,
    required String senderId,
    required String senderName,
    required double latitude,
    required double longitude,
    required String address,
    String? notes,
    required bool isMine,
  }) {
    return ChatMessage(
      id: id,
      jobId: jobId,
      senderId: senderId,
      senderName: senderName,
      type: ChatMessageType.location,
      content: 'Ubicación física compartida',
      latitude: latitude,
      longitude: longitude,
      address: address,
      notes: notes,
      createdAt: DateTime.now(),
      isMine: isMine,
    );
  }
}
