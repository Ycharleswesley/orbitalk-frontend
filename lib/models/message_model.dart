enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
}

class MessageModel {
  final String id;
  final String text;
  final String time;
  final bool isSentByMe;
  final MessageStatus status;
  final bool isTranslated;

  MessageModel({
    required this.id,
    required this.text,
    required this.time,
    required this.isSentByMe,
    this.status = MessageStatus.sent,
    this.isTranslated = false,
  });
}

// Fake message data for a chat
List<MessageModel> getChatMessages() {
  return [
    MessageModel(
      id: '1',
      text: 'Hi',
      time: '12:00PM',
      isSentByMe: false,
      status: MessageStatus.delivered,
    ),
    MessageModel(
      id: '2',
      text: 'Hi Hello !!!',
      time: '04:06PM',
      isSentByMe: true,
      status: MessageStatus.read,
    ),
  ];
}
