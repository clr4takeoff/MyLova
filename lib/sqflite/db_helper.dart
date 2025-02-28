import 'package:emo_diary_project/models/diary_content_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const String tableName = 'Diary_table';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  // Private Constructor
  DBHelper._internal();

  // Factory constructor
  factory DBHelper() {
    return _instance;
  }

  // Database getter
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // Init database
  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'diary_database.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  // Create databse Structure
  Future _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE $tableName (
    id TEXT PRIMARY KEY,
    date TEXT,
    content TEXT,
    show_comment INTEGER,
    comment TEXT
  )''');
  }


  // Create new data
  Future<void> insert(DiaryContent diaryContent) async {
    final db = await database;
    await db.insert(tableName, diaryContent.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Read all
  // Future<List<DiaryContent>> queryAll() async {
  //   final db = await database;
  //   var res = await db.query(tableName);
  //   return res
  //           .map((e) => DiaryContent(
  //               id: e['id'] as int,
  //               date: e['date'] as DateTime,
  //               prompt: e['prompt'] as String,
  //               content: e['content'] as String,
  //               comment: e['comment'] as String))
  //           .toList();
  // }

  Future<int> updateRetrospectById(String id, int isRetrospect) async {
    final db = await database;
    return await db.update(tableName, {'is_retrospected': isRetrospect},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    final db = await database;
    return await db.query(tableName);
  }

  Future<List<Map<String, dynamic>>> queryRetrospect() async {
    final db = await database;
    return await db
        .query(tableName, where: 'is_retrospected = ?', whereArgs: [0]);
  }

  // Update when received comment
  Future<int> updateShowCommentById(String id, int showComment) async {
    final db = await database;
    return await db.update(tableName, {'show_comment': showComment},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateShowSurveyById(String id, int showSurvey) async {
    final db = await database;
    return await db.update(tableName, {'show_survey': showSurvey},
        where: 'id = ?', whereArgs: [id]);
  }

  // Delete
  Future<int> delete(String id) async {
    final db = await database;
    return await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }


  Future<void> updateCommentById(String diaryId, String comment) async {
    final db = await database;

    await db.update(
      'Diary_table',
      {'comment': comment},
      where: 'id = ?',
      whereArgs: [diaryId],
    );
  }
}
