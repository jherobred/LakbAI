import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kontrata/chat/chat_history.dart';

Conversation chat(String id, String q, {int minutes = 0}) => Conversation(
      id: id,
      updatedAt: DateTime(2026, 10, 10, 8).add(Duration(minutes: minutes)),
      messages: [
        SavedMessage(fromUser: true, text: q, topics: const ['salary']),
        const SavedMessage(fromUser: false, text: '**Yes.** You can claim it.\n- Source: RA 8042', sources: ['kb1'], byAi: true),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No private folder in unit tests, so the store runs in memory; the logic is the same.
  test('newest chat first, and saving again moves it to the top', () async {
    final h = ChatHistory.instance;
    await h.deleteAll();
    await h.save(chat('a', 'First'));
    await h.save(chat('b', 'Second'));
    expect((await h.list()).map((c) => c.id), ['b', 'a']);
    await h.save(chat('a', 'First again'));
    final list = await h.list();
    expect(list.map((c) => c.id), ['a', 'b']);
    expect(list.first.title, 'First again');
  });

  test('keeps at most maxChats and deletes one or all', () async {
    final h = ChatHistory.instance;
    await h.deleteAll();
    for (var i = 0; i < ChatHistory.maxChats + 5; i++) {
      await h.save(chat('c$i', 'Q$i'));
    }
    expect((await h.list()).length, ChatHistory.maxChats);
    await h.delete('c${ChatHistory.maxChats + 4}');
    expect((await h.list()).any((c) => c.id == 'c${ChatHistory.maxChats + 4}'), isFalse);
    await h.deleteAll();
    expect(await h.list(), isEmpty);
  });

  test('title, preview and JSON round trip', () {
    final c = chat('x', 'Is my salary too low?');
    expect(c.title, 'Is my salary too low?');
    expect(c.preview, 'Yes. You can claim it. - Source: RA 8042');
    expect(c.questionCount, 1);
    final back = Conversation.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.id, 'x');
    expect(back.messages.length, 2);
    expect(back.messages.last.byAi, isTrue);
    expect(back.messages.last.sources, ['kb1']);
    expect(back.messages.first.topics, ['salary']);
  });
}
