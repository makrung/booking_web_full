import 'package:flutter/material.dart';
import 'services/points_service.dart';

class AdminPointsRequestsPage extends StatefulWidget {
	const AdminPointsRequestsPage({super.key});

	@override
	State<AdminPointsRequestsPage> createState() => _AdminPointsRequestsPageState();
}

class _AdminPointsRequestsPageState extends State<AdminPointsRequestsPage> {
	bool _loading = true;
	String? _error;
	List<dynamic> _requests = [];
	String _q = '';
	String _status = 'all'; // all|pending|approved|denied
	int _shown = 30;
	 String _requestsSort = 'none'; // none|latest|oldest

	@override
	void initState() {
		super.initState();
		_load();
	}

	Future<void> _load() async {
		setState(() {
			_loading = true;
			_error = null;
		});
		try {
			final list = await PointsService.listAllRequests();
			setState(() {
				_requests = list;
			});
		} catch (e) {
			setState(() {
				_error = 'โหลดคำขอไม่สำเร็จ: $e';
			});
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	// Normalize various timestamp representations into a DateTime.
	DateTime _toDateTime(dynamic v) {
		if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
		if (v is DateTime) return v;
		if (v is int) {
			if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
			return DateTime.fromMillisecondsSinceEpoch(v * 1000);
		}
		if (v is double) {
			final iv = v.toInt();
			if (iv > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(iv);
			return DateTime.fromMillisecondsSinceEpoch(iv * 1000);
		}
		if (v is String) {
			try { return DateTime.parse(v); } catch (_) {}
			final n = num.tryParse(v);
			if (n != null) {
				final iv = n.toInt();
				if (iv > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(iv);
				return DateTime.fromMillisecondsSinceEpoch(iv * 1000);
			}
		}
		if (v is Map) {
			final s = v['seconds'] ?? v['_seconds'];
			final ns = v['nanoseconds'] ?? v['_nanoseconds'] ?? v['nanos'];
			if (s != null) {
				final secs = (s is int) ? s : int.tryParse(s.toString()) ?? 0;
				final nanos = (ns is int) ? ns : int.tryParse(ns.toString()) ?? 0;
				return DateTime.fromMillisecondsSinceEpoch(secs * 1000 + (nanos / 1000000).toInt());
			}
		}
		return DateTime.fromMillisecondsSinceEpoch(0);
	}

	Future<void> _decide(String id, String decision) async {
		if (decision == 'approve') {
			int selected = 10;
			String note = '';
			await showDialog(
				context: context,
				builder: (ctx) => StatefulBuilder(
					builder: (ctx, setS) => AlertDialog(
						title: const Text('อนุมัติคำขอและเพิ่มคะแนน'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								DropdownButton<int>(
									value: selected,
									items: const [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
											.map((e) => DropdownMenuItem(value: e, child: Text('$e คะแนน')))
											.toList(),
									onChanged: (v) => setS(() => selected = v ?? selected),
								),
								TextField(
									decoration: const InputDecoration(labelText: 'ข้อความถึงผู้ใช้'),
									onChanged: (v) => note = v,
								),
							],
						),
						actions: [
							TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
							ElevatedButton(
								onPressed: () async {
									final resp = await PointsService.decideRequest(
										id: id,
										decision: 'approve',
										points: selected,
										message: note,
									);
									if (context.mounted) {
										Navigator.pop(ctx);
										ScaffoldMessenger.of(context).showSnackBar(
											SnackBar(content: Text(resp['message'] ?? 'สำเร็จ')),
										);
										await _load();
									}
								},
								child: const Text('ยืนยัน'),
							),
						],
					),
				),
			);
		} else {
			String note = '';
			await showDialog(
				context: context,
				builder: (ctx) => AlertDialog(
					title: const Text('ปฏิเสธคำขอ'),
					content: TextField(
						decoration: const InputDecoration(labelText: 'เหตุผล'),
						onChanged: (v) => note = v,
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
						ElevatedButton(
							onPressed: () async {
								final resp = await PointsService.decideRequest(
									id: id,
									decision: 'deny',
									message: note,
								);
								if (context.mounted) {
									Navigator.pop(ctx);
									ScaffoldMessenger.of(context).showSnackBar(
										SnackBar(content: Text(resp['message'] ?? 'สำเร็จ')),
									);
									await _load();
								}
							},
							child: const Text('ยืนยัน'),
						),
					],
				),
			);
		}
	}

	Future<void> _changeStatusFlow(Map req) async {
		final id = (req['id'] ?? req['_id'] ?? '').toString();
		final String currentStatus = (req['status']?.toString() ?? 'pending').toLowerCase();
		int selected = int.tryParse('${req['approvedPoints'] ?? req['requestedPoints'] ?? 10}') ?? 10;
		String note = '';
		await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
			return AlertDialog(
				title: const Text('เปลี่ยนสถานะคำขอคะแนน'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						DropdownButton<String>(
							value: currentStatus,
							items: const [
								DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ')),
								DropdownMenuItem(value: 'approved', child: Text('อนุมัติ')),
								DropdownMenuItem(value: 'denied', child: Text('ปฏิเสธ')),
							],
							onChanged: (v) {
								// no-op here; we only show current and provide quick actions below
							},
						),
						// หากเป้าหมายคืออนุมัติ ต้องเลือกคะแนน
						DropdownButton<int>(
							value: selected,
							items: const [10,20,30,40,50,60,70,80,90,100]
									.map((e) => DropdownMenuItem(value: e, child: Text('อนุมัติที่ $e คะแนน')))
									.toList(),
							onChanged: (v) => setS(() => selected = v ?? selected),
						),
						TextField(
							decoration: const InputDecoration(labelText: 'หมายเหตุถึงผู้ใช้ (ถ้ามี)'),
							onChanged: (v) => note = v,
						),
						const SizedBox(height: 8),
						Text('คำแนะนำ: หากถูกอนุมัติแล้วและต้องการแก้เป็นรอดำเนินการ/ปฏิเสธ ระบบจะหักคืนคะแนนเดิมให้อัตโนมัติ'),
					],
				),
				actions: [
					// Quick actions
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
					if (currentStatus == 'approved') ...[
						OutlinedButton(onPressed: () async {
							final resp = await PointsService.changeStatus(id: id, status: 'pending', message: note);
							if (context.mounted) {
								Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'ยกเลิกการอนุมัติแล้ว')));
								await _load();
							}
						}, child: const Text('ยกเลิกอนุมัติ → รอดำเนินการ')),
						OutlinedButton(onPressed: () async {
							final resp = await PointsService.changeStatus(id: id, status: 'denied', message: note);
							if (context.mounted) {
								Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'ยกเลิกการอนุมัติและปฏิเสธแล้ว')));
								await _load();
							}
						}, child: const Text('ยกเลิกอนุมัติ → ปฏิเสธ')),
						ElevatedButton(onPressed: () async {
							final resp = await PointsService.changeStatus(id: id, status: 'approved', points: selected, message: note);
							if (context.mounted) {
								Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'ปรับอนุมัติแล้ว')));
								await _load();
							}
						}, child: const Text('ปรับคะแนนที่อนุมัติ')),
					] else if (currentStatus == 'pending') ...[
						OutlinedButton(onPressed: () async {
							final resp = await PointsService.changeStatus(id: id, status: 'denied', message: note);
							if (context.mounted) {
								Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'ปฏิเสธแล้ว')));
								await _load();
							}
						}, child: const Text('ปฏิเสธ')),
						ElevatedButton(onPressed: () async {
							final resp = await PointsService.changeStatus(id: id, status: 'approved', points: selected, message: note);
							if (context.mounted) {
								Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'อนุมัติแล้ว')));
								await _load();
							}
						}, child: const Text('อนุมัติ')),
					] else ...[
						OutlinedButton(onPressed: () async {
							final resp = await PointsService.changeStatus(id: id, status: 'pending', message: note);
							if (context.mounted) {
								Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'ตั้งเป็นรอดำเนินการแล้ว')));
								await _load();
							}
						}, child: const Text('ตั้งเป็นรอดำเนินการ')),
						ElevatedButton(onPressed: () async {
							final resp = await PointsService.changeStatus(id: id, status: 'approved', points: selected, message: note);
							if (context.mounted) {
								Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'อนุมัติแล้ว')));
								await _load();
							}
						}, child: const Text('อนุมัติ')),
					],
				],
			);
		}));
	}

	Future<void> _editRequest(Map req) async {
		final id = (req['id'] ?? req['_id'] ?? '').toString();
		int selected = int.tryParse('${req['requestedPoints'] ?? req['points'] ?? 10}') ?? 10;
		String reason = req['reason']?.toString() ?? '';
		await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
			return AlertDialog(
				title: const Text('แก้ไขคำขอ'),
				content: Column(mainAxisSize: MainAxisSize.min, children: [
					DropdownButton<int>(
						value: selected,
						items: const [10,20,30,40,50,60,70,80,90,100]
								.map((e) => DropdownMenuItem(value: e, child: Text('$e คะแนน')))
								.toList(),
						onChanged: (v) => setS(() => selected = v ?? selected),
					),
					TextField(decoration: const InputDecoration(labelText: 'เหตุผล'), controller: TextEditingController(text: reason), onChanged: (v) => reason = v),
				]),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
					ElevatedButton(onPressed: () async {
						final resp = await PointsService.editRequest(id: id, requestedPoints: selected, reason: reason);
						if (context.mounted) {
							Navigator.pop(ctx);
							ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? 'บันทึกแล้ว')));
							await _load();
						}
					}, child: const Text('บันทึก')),
				],
			);
		}));
	}

	Future<void> _deleteRequest(String id) async {
		final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('ยืนยันการลบ'), content: const Text('ต้องการลบคำขอนี้หรือไม่?'), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('ยกเลิก')), ElevatedButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('ลบ'))]));
		if (ok != true) return;
		final resp = await PointsService.deleteRequest(id);
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message'] ?? resp['error'] ?? 'ลบแล้ว')));
		await _load();
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) return const Center(child: CircularProgressIndicator());
		if (_error != null) {
			return Center(
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
			);
		}

		return RefreshIndicator(
			onRefresh: _load,
			child: Column(
				children: [
					Padding(
						padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
						child: Row(
							children: [
								Expanded(
									child: TextField(
										decoration: const InputDecoration(
											prefixIcon: Icon(Icons.search),
											hintText: 'ค้นหาด้วยชื่อ อีเมล สถานะ เหตุผล หรือจำนวน',
										),
										onChanged: (v) => setState(() {
											_q = v;
											_shown = 30;
										}),
									),
								),
								const SizedBox(width: 12),
													DropdownButton<String>(
																					value: _status,
																					items: const [
																							DropdownMenuItem(value: 'all', child: Text('ทุกสถานะ')),
																							DropdownMenuItem(value: 'pending', child: Text('กำลังพิจารณา')),
																							DropdownMenuItem(value: 'approved', child: Text('อนุมัติแล้ว')),
																							DropdownMenuItem(value: 'denied', child: Text('ปฏิเสธแล้ว')),
																					],
																					onChanged: (v) => setState(() => _status = v ?? 'all'),
																			),
																			const SizedBox(width: 12),
																			DropdownButton<String>(
																				value: _requestsSort,
																				items: const [
																					DropdownMenuItem(value: 'none', child: Text('เรียง: ปกติ')),
																					DropdownMenuItem(value: 'latest', child: Text('เรียง: ล่าสุด')),
																					DropdownMenuItem(value: 'oldest', child: Text('เรียง: เก่า')),
																				],
																				onChanged: (v) => setState(() => _requestsSort = v ?? 'none'),
																			),
							],
						),
					),
					Expanded(
						child: Builder(
							builder: (context) {
								final q = _q.toLowerCase();
								final filtered = _requests.where((r) {
									final Map req = (r is Map) ? r : {};
									final user = (req['user'] is Map) ? (req['user'] as Map) : {};
									final name = ('${user['firstName'] ?? ''} ${user['lastName'] ?? ''}').trim().toLowerCase();
									final email = (user['email']?.toString() ?? '').toLowerCase();
									final status = (req['status']?.toString() ?? '').toLowerCase();
									final reason = (req['reason']?.toString() ?? '').toLowerCase();
									final points = (req['requestedPoints']?.toString() ?? req['points']?.toString() ?? '').toLowerCase();
									final matchText = name.contains(q) || email.contains(q) || status.contains(q) || reason.contains(q) || points.contains(q);
									final matchStatus = _status == 'all' || status == _status;
									return matchText && matchStatus;
								}).toList();

																// Apply client-side sorting by createdAt if requested
																List<dynamic> sortedFiltered = List.from(filtered);
																								if (_requestsSort == 'latest') {
																									sortedFiltered.sort((a, b) => _toDateTime(b['createdAt']).compareTo(_toDateTime(a['createdAt'])));
																								} else if (_requestsSort == 'oldest') {
																									sortedFiltered.sort((a, b) => _toDateTime(a['createdAt']).compareTo(_toDateTime(b['createdAt'])));
																								}

																if (sortedFiltered.isEmpty) {
									return ListView(children: const [SizedBox(height: 140), Center(child: Text('ไม่พบผลลัพธ์'))]);
								}
																final showing = sortedFiltered.take(_shown).toList();
								return ListView.builder(
									padding: const EdgeInsets.all(16),
									itemCount: showing.length + 1,
									itemBuilder: (ctx, i) {
										if (i == showing.length) {
											final more = filtered.length - showing.length;
											if (more <= 0) return const SizedBox.shrink();
											return Center(
												child: TextButton(
													onPressed: () => setState(() => _shown += 30),
													child: Text('โหลดเพิ่ม (+${more.clamp(0, 30)})'),
												),
											);
										}

										final r = showing[i];
										final Map req = (r is Map) ? r : {};
										final id = (req['id'] ?? req['_id'] ?? '').toString();
										final String name = (() {
											final user = req['user'];
											if (user is Map) {
												final fn = user['firstName']?.toString() ?? '';
												final ln = user['lastName']?.toString() ?? '';
												if (fn.isNotEmpty || ln.isNotEmpty) return ('$fn $ln').trim();
											}
											final un = req['userName']?.toString();
											return (un == null || un.isEmpty) ? 'ไม่ทราบชื่อ' : un;
										})();
										final String email = (() {
											final user = req['user'];
											if (user is Map) return user['email']?.toString() ?? '';
											return '';
										})();
										final int requestedPoints = int.tryParse('${req['requestedPoints'] ?? req['points'] ?? 0}') ?? 0;
										final String reason = req['reason']?.toString() ?? '';
										final String status = req['status']?.toString() ?? 'pending';
										final int currentPoints = int.tryParse('${req['currentPoints'] ?? 0}') ?? 0;
										final int penaltiesCount = int.tryParse('${req['penaltiesCount'] ?? 0}') ?? 0;
										final int adminGivenCount = int.tryParse('${req['adminGivenCount'] ?? 0}') ?? 0;

										Color statusColor;
										switch (status) {
											case 'approved':
												statusColor = Colors.green;
												break;
											case 'denied':
												statusColor = Colors.red;
												break;
											default:
												statusColor = Colors.orange;
										}

										return Card(
											margin: const EdgeInsets.only(bottom: 12),
											child: Padding(
												padding: const EdgeInsets.all(12),
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Row(
															mainAxisAlignment: MainAxisAlignment.spaceBetween,
															children: [
																Expanded(
																	child: Column(
																		crossAxisAlignment: CrossAxisAlignment.start,
																		children: [
																			Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
																			if (email.isNotEmpty) Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
																		],
																	),
																),
																Container(
																	padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
																	decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
																	child: Text(
																		status == 'pending' ? 'รอดำเนินการ' : (status == 'approved' ? 'อนุมัติ' : 'ปฏิเสธ'),
																		style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
																	),
																),
															],
														),
														const SizedBox(height: 8),
														Text('ขอเพิ่ม: $requestedPoints คะแนน'),
														if (reason.isNotEmpty) Text('เหตุผล: $reason', style: TextStyle(color: Colors.grey[700])),
														const SizedBox(height: 8),
														Wrap(spacing: 12, runSpacing: 6, children: [
															Chip(label: Text('คะแนนปัจจุบัน: $currentPoints'), avatar: const Icon(Icons.stars, size: 16, color: Colors.teal), backgroundColor: Colors.teal.withValues(alpha: 0.1)),
															Chip(label: Text('เคยได้จากแอดมิน: $adminGivenCount ครั้ง'), avatar: const Icon(Icons.volunteer_activism, size: 16, color: Colors.blue), backgroundColor: Colors.blue.withValues(alpha: 0.1)),
															Chip(label: Text('เคยถูกหัก: $penaltiesCount ครั้ง'), avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red), backgroundColor: Colors.red.withValues(alpha: 0.08)),
														]),
														const SizedBox(height: 8),
														if (status == 'pending')
															Row(
																children: [
																	ElevatedButton.icon(
																		onPressed: () => _decide(id, 'approve'),
																		icon: const Icon(Icons.check),
																		label: const Text('อนุมัติ'),
																		style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
																	),
																	const SizedBox(width: 8),
																	OutlinedButton.icon(
																		onPressed: () => _decide(id, 'deny'),
																		icon: const Icon(Icons.close, color: Colors.red),
																		label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
																		style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
																	),
																	const SizedBox(width: 8),
																	OutlinedButton.icon(
																		onPressed: () => _editRequest(req),
																		icon: const Icon(Icons.edit),
																		label: const Text('แก้ไขคำขอ'),
																	),
																],
															),
														Row(
															children: [
																TextButton.icon(
																	onPressed: () => _changeStatusFlow(req),
																	icon: const Icon(Icons.sync_alt),
																	label: const Text('เปลี่ยนสถานะ/แก้การอนุมัติ'),
																),
															],
														),
														Row(
															children: [
																const Spacer(),
																TextButton.icon(
																	onPressed: () => _deleteRequest(id),
																	icon: const Icon(Icons.delete, color: Colors.red),
																	label: const Text('ลบคำขอ', style: TextStyle(color: Colors.red)),
																),
															],
														),
													],
												),
											),
										);
									},
								);
							},
						),
					),
				],
			),
		);
	}
}

