import 'package:p3p/p3p.dart';
import 'package:ssmdc/ssmdc.dart';
import 'package:uuid/uuid.dart';

Future<bool> handlerCore(P3pSSMDC p3pssmdc, UserInfo ui, Event evt) async {
  if (evt.eventType != EventType.message) return false;
  final msg = Message.fromEvent(evt, true, ui.publicKey.fingerprint);
  if (msg == null) return false;
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
''', type: MessageType.text).toJson(),
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
                  type: MessageType.text)
              .toJson(),
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
            fselm: await ui.fileStore.getFileStoreElement(p3pssmdc.p3p),
            publickey: p3pssmdc.p3p.privateKey.toPublic,
            username: si.name ?? 'unknown username (ir)',
          ).toJson(),
        ),
      );
    }
    ui.addEvent(
      p3pssmdc.p3p,
      Event(
        eventType: EventType.message,
        data: EventMessage(
                text: 'Title updated to: `$title`', type: MessageType.text)
            .toJson(),
      )..uuid = evt.uuid,
    );
    return true;
  }

  return false; // continue broadcasting
}
