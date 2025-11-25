import 'package:flutter/material.dart';
import 'services/points_service.dart';
import 'package:intl/intl.dart';

class MessagesPage extends StatefulWidget {
	const MessagesPage({super.key});

	@override
	State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
	bool _loading = true;
	String? _error;
	List<dynamic> _messages = [];
	int _unread = 0;

	@override
	void initState() {
		super.initState();
		_load();
	}

	Future<void> _load() async {
		setState(() { _loading = true; _error = null; });
		try {
			final msgs = await PointsService.inboxMessages();
			final unread = await PointsService.unreadMessagesCount();
			setState(() { _messages = msgs; _unread = unread; });
		} catch (e) {
			setState(() { _error = 'โหลดข้อความล้มเหลว: $e'; });
		} finally {
			setState(() { _loading = false; });
		}
	}

	Future<void> _markRead(String id) async {
		try {
			await PointsService.markMessageRead(id);
			await _load();
		} catch (_) {}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Row(children: [
					const Text('กล่องข้อความ'),
					const SizedBox(width: 8),
					if (_unread > 0)
						Container(
							padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
							decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
							child: Text('$_unread', style: const TextStyle(color: Colors.white, fontSize: 12)),
						),
				]),
			),
			body: _loading
					? const Center(child: CircularProgressIndicator())
					: _error != null
							? Center(
									child: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											const Icon(Icons.error, color: Colors.red),
											const SizedBox(height: 8),
											Text(_error!),
											const SizedBox(height: 8),
											ElevatedButton(onPressed: _load, child: const Text('ลองใหม่')),
										],
									),
								)
							: RefreshIndicator(
									onRefresh: _load,
									child: _messages.isEmpty
											? ListView(children: const [
													SizedBox(height: 160),
													Center(child: Text('ยังไม่มีข้อความ')),
												])
											: ListView.separated(
													padding: const EdgeInsets.all(12),
													itemBuilder: (c, i) {
														final m = _messages[i] as Map<String, dynamic>;
														final read = m['read'] == true;
														DateTime? dt;
														try { dt = m['createdAt'] != null ? DateTime.parse(m['createdAt']) : null; } catch (_) {}
														final dateText = dt != null ? DateFormat('dd/MM/yyyy HH:mm').format(dt) : '';
														return ListTile(
															leading: Icon(read ? Icons.mark_email_read : Icons.mark_email_unread, color: read ? Colors.grey : Colors.teal),
															title: Text(m['title'] ?? 'ข้อความ', style: TextStyle(fontWeight: read ? FontWeight.w400 : FontWeight.w600)),
															subtitle: Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																children: [
																	const SizedBox(height: 4),
																	Text(m['body'] ?? '-'),
																	if (dateText.isNotEmpty) Text(dateText, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
																],
															),
															trailing: !read ? TextButton(onPressed: () => _markRead(m['id']), child: const Text('ทำเครื่องหมายอ่าน')) : null,
														);
													},
													separatorBuilder: (_, __) => const Divider(height: 1),
													itemCount: _messages.length,
												),
								),
		);
	}
}

