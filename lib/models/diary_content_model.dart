class DiaryContent {
  final String id;
  final String date;
  final String content;
  late final int showComment;
  final String comment;

  DiaryContent(
      {required this.id,
      required this.date,
      required this.content,
      required this.showComment,
      required this.comment,});

  factory DiaryContent.fromMap(Map<String, dynamic> map) {
    return DiaryContent(
        id: map['id'],
        date: map['date'],
        content: map['content'],
        showComment: map['show_comment'],
        comment: map['comment']);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'content': content,
      'show_comment': showComment,
      'comment': comment
    };
  }
}
