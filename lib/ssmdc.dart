import 'dart:io';

import 'package:dart_pg/dart_pg.dart' as pgp;
import 'package:p3p/p3p.dart';
import 'package:p3p/src/database/drift.dart' as db;

import 'package:path/path.dart' as p;
import 'package:ssmdc/db/filedatabase.dart';
import 'package:ssmdc/handlers/groupinfo.dart';

const passpharse = 'passpharse';

Future<void> generatePrivkey(File storedPgp) async {
  final encPgp = await pgp.OpenPGP.generateKey(
    ['simplebot <no-reply@mrcyjanek.net>'],
    'passpharse',
  );
  await storedPgp.writeAsString(encPgp.armor());
}

class P3pSSMDC {
  P3pSSMDC({
    required this.p3p,
    required this.ssmdcdb,
  });
  P3p p3p;
  FileDatabase ssmdcdb;
  static Future<P3pSSMDC> createGroup(String fileStorePath,
      {required bool scheduleTasks, required bool listen}) async {
    final storedPgp = File(p.join(fileStorePath, 'privkey.pgp'));
    if (!await storedPgp.exists()) {
      await storedPgp.create(recursive: true);
      await generatePrivkey(storedPgp);
      print('Privkey generated and stored in ${storedPgp.path}');
    }
    // create client session
    final p3p = await P3p.createSession(
        fileStorePath,
        await storedPgp.readAsString(),
        'passpharse',
        db.DatabaseImplDrift(
            dbFolder: p.join(fileStorePath, 'db-drift'),
            singularFileStore: true),
        scheduleTasks: scheduleTasks,
        listen: listen);
    final p3pssmdc = P3pSSMDC(
      p3p: p3p,
      ssmdcdb: FileDatabase(
        storePath: (Directory(p.join(fileStorePath, 'db-ssmdc'))
              ..createSync(recursive: true))
            .path,
      ),
    );
    p3pssmdc.p3p.onEventCallback.add(p3pssmdc.eventCallback);
    return p3pssmdc;
  }

  Future<List<UserInfo>> getGroupMembers() async {
    final List<dynamic> members = await ssmdcdb.get('members') ?? [];
    final ret = <UserInfo>[];
    for (var elm in members) {
      ret.add((await p3p.db.getUserInfo(fingerprint: elm.toString()))!);
    }
    return ret;
  }

  Future<void> addGroupMembers(String fingerprint) async {
    print('add0');
    final List<dynamic> members = await ssmdcdb.get('members') ?? [];
    print('add1');
    members.add(fingerprint);
    print('add2');
    await ssmdcdb.set('members', members);
    print('add3');
  }

  Future<void> sendToAll(Event evt) async {
    final users = await getGroupMembers();
    for (var ui in users) {
      await ui.addEvent(p3p, evt);
    }
  }

  final handlers = [handlerCore];

  Future<bool> eventCallback(P3p p3p, Event evt, UserInfo ui) async {
    if (ui.publicKey.fingerprint ==
        (await p3p.getSelfInfo()).publicKey.fingerprint) return true;
    print('[ssmdc]: ${ui.id}. ${ui.name} event: ${evt.eventType}');
    // p3p.sendMessage(ui, 'okokokok');
    switch (evt.eventType) {
      case EventType.introduce:
        final List<dynamic> gm = await ssmdcdb.get('members') ?? [];
        print(gm);
        if (!gm.contains(ui.publicKey.fingerprint)) {
          if (gm.isEmpty) {
            await ssmdcdb.set('admins', [ui.publicKey.fingerprint]);
          }
          await addGroupMembers(ui.publicKey.fingerprint);
          final welcomeEvt = Event(
            eventType: EventType.message,
            data: EventMessage(
              text: '**${ui.name}:** have joined the group!',
              type: MessageType.service,
            ),
          );
          await sendToAll(
            welcomeEvt,
          );
          await ui.addEvent(p3p, evt);
        }
        return false; // We want to process introduction anyway
      case EventType.message:
        bool broadcast = true;
        for (var h in handlers) {
          if (await h(this, ui, evt)) {
            broadcast = false;
          }
        }
        if (broadcast) {
          await sendToAll(
            Event(
              eventType: EventType.message,
              data: EventMessage(
                text: '**${ui.name}:** ${(evt.data as EventMessage).text}',
                type: MessageType.text,
              ),
            )..uuid = evt.uuid,
          );
        }
        await ui.relayEvents(
          p3p,
          (await p3p.db.getPublicKey(fingerprint: p3p.privateKey.fingerprint))!,
        );
        return true; // We don't care about that event anymore
      default:
        return false;
    }
  }

  Future<bool> isAdmin(UserInfo ui) async {
    final List<dynamic> gm = await ssmdcdb.get('admins') ?? [];
    return gm.contains(ui.publicKey.fingerprint);
  }
}
