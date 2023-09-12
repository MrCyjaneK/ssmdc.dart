import 'package:p3p/p3p.dart';
import 'package:ssmdc/ssmdc.dart';
import 'package:uuid/uuid.dart';

Future<bool> handlerCore(P3pSSMDC p3pssmdc, UserInfo ui, Event evt) async {
  if (evt.eventType != EventType.message) return false;
  final msg = Message.fromEvent(evt, ui.publicKey.fingerprint, incoming: true);
  if (msg.text.startsWith('/leave')) {
    ui.addMessage(
        p3pssmdc.p3p,
        Message(
            text: "You have left the chat. Make sure to delete the chat from "
                "your chat list or you may automatically rejoin.",
            uuid: Uuid().v4(),
            incoming: false,
            roomFingerprint: ui.publicKey.fingerprint));
    p3pssmdc.removeGroupMember(ui.publicKey.fingerprint);
  }
  if (msg.text.startsWith('/groupinfo')) {
    ui.addEvent(
      p3pssmdc.p3p,
      Event(
        eventType: EventType.message,
        data: EventMessage(text: '''## Group Info
publickey:
```pgp
${p3pssmdc.p3p.privateKey.toPublic.armor()}
```

admin: ${await p3pssmdc.isAdmin(ui)}
''', type: MessageType.text),
      )..uuid = evt.uuid,
    );
    return true;
  } else if (msg.text.startsWith('/title ')) {
    final title = msg.text.substring('/title '.length);
    if (title.length < 3 || !(await p3pssmdc.isAdmin(ui))) {
      ui.addEvent(
        p3pssmdc.p3p,
        Event(
          eventType: EventType.message,
          data: EventMessage(
              text: 'Title too short or no permissions',
              type: MessageType.text),
        )..uuid = evt.uuid,
      );
      return true;
    }
    final si = await p3pssmdc.p3p.getSelfInfo();
    si.name = title;
    final users = await p3pssmdc.p3p.db.getAllUserInfo();
    for (var cui in users) {
      cui.addEvent(
        p3pssmdc.p3p,
        Event(
          eventType: EventType.introduce,
          destinationPublicKey: cui.publicKey,
          data: EventIntroduce(
            endpoint: si.endpoint,
            publickey: p3pssmdc.p3p.privateKey.toPublic,
            username: si.name ?? 'unknown username (ir)',
          ),
        ),
      );
      cui.addEvent(
        p3pssmdc.p3p,
        Event(
          eventType: EventType.fileMetadata,
          data: EventFileMetadata(
            files: await ui.fileStore.getFileStoreElement(p3pssmdc.p3p),
          ),
        ),
      );
    }
    ui.addEvent(
      p3pssmdc.p3p,
      Event(
        eventType: EventType.message,
        data: EventMessage(
            text: 'Title updated to: `$title`', type: MessageType.service),
      )..uuid = evt.uuid,
    );
    return true;
  }

  return false; // continue broadcasting
}
