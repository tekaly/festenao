import 'package:festenao_common/sembast/projects_db.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  var userId = 'test_user';
  test('isAdmin', () {
    var readOnly = DbProject()
      ..read.v = true
      ..write.v = false
      ..admin.v = false;
    expect(readOnly.isRead, isTrue);
    expect(readOnly.isWrite, isFalse);
    expect(readOnly.isAdmin, isFalse);
    var admin = DbProject()..admin.v = true;
    expect(admin.isAdmin, isTrue);
  });
  test('database per name', () async {
    var factory = newDatabaseFactoryMemory();
    var db1 = ProjectsDb(factory: factory, name: 'p1-projects.db');
    var db2 = ProjectsDb(factory: factory, name: 'p2-projects.db');
    await db1.ready;
    await db2.ready;
    expect(db1.db.path, 'p1-projects.db');
    expect(db2.db.path, 'p2-projects.db');
    await db1.addProject(
      DbProject()
        ..uid.v = 'project1'
        ..userId.v = userId,
    );
    expect(await db1.getProject('project1', userId: userId), isNotNull);
    expect(await db2.getProject('project1', userId: userId), isNull);
    await db1.db.close();
    await db2.db.close();
  });
  test('legacy projects kept in a new named database', () async {
    var factory = newDatabaseFactoryMemory();
    // Before, every name opened projectsDbName.
    var legacyDb = await factory.openDatabase(projectsDbName);
    initDbProjectsBuilders();
    await dbProjectStore.add(
      legacyDb,
      DbProject()
        ..uid.v = 'project1'
        ..userId.v = userId,
    );
    await legacyDb.close();

    var db = ProjectsDb(factory: factory, name: 'p1-projects.db');
    await db.ready;
    expect(await db.getProject('project1', userId: userId), isNotNull);
    // Imported once only.
    await db.deleteProject('project1', userId: userId);
    await db.db.close();
    db = ProjectsDb(factory: factory, name: 'p1-projects.db');
    await db.ready;
    expect(await db.getProject('project1', userId: userId), isNull);
    await db.db.close();
  });
}
