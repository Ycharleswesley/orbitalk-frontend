class ChatModel {
  final String name;
  final String message;
  final String time;
  final String avatarUrl;
  final bool isGroup;
  final int unreadCount;
  final bool isOnline;

  ChatModel({
    required this.name,
    required this.message,
    required this.time,
    required this.avatarUrl,
    this.isGroup = false,
    this.unreadCount = 0,
    this.isOnline = false,
  });
}

// Fake chat data
List<ChatModel> getChatData() {
  return [
    ChatModel(
      name: 'Ram',
      message: 'Hi',
      time: '12:06 PM',
      avatarUrl: '',
      isOnline: true,
    ),
    ChatModel(
      name: 'Raj',
      message: 'How are you?',
      time: '8:09 AM',
      avatarUrl: '',
      isOnline: false,
    ),
    ChatModel(
      name: 'Sita',
      message: 'I am fine !!!',
      time: '30/09/25',
      avatarUrl: '',
      unreadCount: 2,
      isOnline: true,
    ),
    ChatModel(
      name: 'Sai',
      message: 'నాకు ఎండిప్రయ్?',
      time: '29/09/25',
      avatarUrl: '',
      unreadCount: 1,
      isOnline: false,
    ),
    ChatModel(
      name: 'Ramesh',
      message: 'మీరు మీరు',
      time: '25/09/25',
      avatarUrl: '',
      isOnline: true,
    ),
    ChatModel(
      name: 'Suresh',
      message: 'क्या आप खाना हो',
      time: '21/09/25',
      avatarUrl: '',
      isOnline: false,
    ),
    ChatModel(
      name: 'Krishna',
      message: 'Good morning!',
      time: '20/09/25',
      avatarUrl: '',
      isOnline: true,
    ),
    ChatModel(
      name: 'Priya',
      message: 'See you tomorrow',
      time: '19/09/25',
      avatarUrl: '',
      unreadCount: 3,
      isOnline: false,
    ),
  ];
}
