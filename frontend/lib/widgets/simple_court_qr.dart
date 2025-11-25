import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../utils/save_file.dart';
import 'package:printing/printing.dart';

/// Widget สำหรับแสดงและจัดการ QR Code ของสนาม
/// ใช้ชื่อสนามเป็นข้อมูลหลักในการสร้าง QR Code
class SimpleCourtQRWidget extends StatefulWidget {
  final String courtName;
  final String courtId;
  final double size;
  final bool showControls;
  final bool isPreview;

  const SimpleCourtQRWidget({
    Key? key,
    required this.courtName,
    required this.courtId,
    this.size = 200.0,
    this.showControls = true,
    this.isPreview = false,
  }) : super(key: key);

  @override
  _SimpleCourtQRWidgetState createState() => _SimpleCourtQRWidgetState();
}

class _SimpleCourtQRWidgetState extends State<SimpleCourtQRWidget> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isGeneratingFile = false;

  /// สร้างข้อมูล QR Code แบบง่าย
  String get qrData => widget.courtName;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ชื่อสนาม
            Text(
              widget.courtName,
              style: TextStyle(
                fontSize: widget.isPreview ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            
            // QR Code
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: widget.size,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  gapless: false,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            
            if (widget.showControls) ...[
              SizedBox(height: 16),
              
              // ข้อมูล QR
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'QR Data: ${widget.courtName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              // ปุ่มควบคุม
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // บันทึกเป็น PDF
                  ElevatedButton.icon(
                    onPressed: _isGeneratingFile ? null : _saveAsPDF,
                    icon: _isGeneratingFile 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.picture_as_pdf, size: 16),
                    label: Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: TextStyle(fontSize: 12),
                    ),
                  ),
                  
                  // บันทึกเป็น JPG
                  ElevatedButton.icon(
                    onPressed: _isGeneratingFile ? null : _saveAsJPG,
                    icon: _isGeneratingFile 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.image, size: 16),
                    label: Text('JPG'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// บันทึกเป็นไฟล์ PDF พร้อมฟอนต์ภาษาไทย
  Future<void> _saveAsPDF() async {
    setState(() => _isGeneratingFile = true);
    
    try {
      // โหลดฟอนต์ภาษาไทยจาก assets และตั้งเป็นธีมเอกสาร (fallback เป็นฟอนต์เดียวกัน)
      pw.Font? thaiRegular;
      pw.Font? thaiBold;
      try {
        thaiRegular = await fontFromAssetBundle('assets/fonts/THSarabunNew.ttf');
        thaiBold = thaiRegular;
      } catch (e) {
        thaiRegular = null;
        thaiBold = null;
      }

      final pdf = pw.Document(
        theme: (thaiRegular != null)
            ? pw.ThemeData.withFont(
                base: thaiRegular,
                bold: thaiBold ?? thaiRegular,
              )
            : null,
      );
      
      // แปลง QR Code เป็น Image
      final qrImageData = await _captureQRAsImage();
      final qrImage = pw.MemoryImage(qrImageData);
      
      // ถ้าไม่มีฟอนต์ไทย ให้เรนเดอร์ข้อความเป็นรูปภาพ (fallback แบบภาพ) ล่วงหน้า
  final bool useImageText = thaiRegular == null;
      pw.MemoryImage? titleImg;
      pw.MemoryImage? nameImg;
      pw.MemoryImage? infoImg;
      pw.MemoryImage? dateImg;
      if (useImageText) {
        titleImg = pw.MemoryImage(await _renderTextAsPng('QR สนามกีฬา', 24, bold: true));
        nameImg = pw.MemoryImage(await _renderTextAsPng(widget.courtName, 20, bold: true));
        infoImg = pw.MemoryImage(await _renderTextAsPng('ข้อมูล QR: ${widget.courtName}', 12));
        dateImg = pw.MemoryImage(await _renderTextAsPng('สร้างเมื่อ: ${DateTime.now().toString().substring(0, 19)}', 10));
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (!useImageText) pw.Text('QR สนามกีฬา', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)) else pw.Image(titleImg!),
                  pw.SizedBox(height: 20),
                  if (!useImageText) pw.Text(widget.courtName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)) else pw.Image(nameImg!),
                  pw.SizedBox(height: 30),
                  pw.Container(
                    padding: pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 2),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Image(qrImage, width: 200, height: 200),
                  ),
                  pw.SizedBox(height: 20),
                  if (!useImageText) pw.Text('ข้อมูล QR: ${widget.courtName}', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)) else pw.Image(infoImg!),
                  pw.SizedBox(height: 10),
                  if (!useImageText) pw.Text('สร้างเมื่อ: ${DateTime.now().toString().substring(0, 19)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)) else pw.Image(dateImg!),
                ],
              ),
            );
          },
        ),
      );
      
      // บันทึกไฟล์
      final fileName = 'QR_${_sanitizeFileName(widget.courtName)}.pdf';
      final bytes = await pdf.save();
      await SaveFileHelper.saveBytes(
        fileName: fileName,
        mimeType: 'application/pdf',
        bytes: bytes,
      );
      
      _showSuccessMessage('บันทึก PDF สำเร็จ: $fileName');
      
    } catch (e) {
      print('Error saving PDF: $e');
      _showErrorMessage('เกิดข้อผิดพลาดในการบันทึก PDF: $e');
    } finally {
      setState(() => _isGeneratingFile = false);
    }
  }

  /// บันทึกเป็นไฟล์ JPG
  Future<void> _saveAsJPG() async {
    setState(() => _isGeneratingFile = true);
    
    try {
      // แปลง QR Code เป็น Image
      final imageData = await _captureQRAsImage();
      
      // บันทึกไฟล์
      final fileName = 'QR_${_sanitizeFileName(widget.courtName)}.jpg';
      await SaveFileHelper.saveBytes(
        fileName: fileName,
        mimeType: 'image/jpeg',
        bytes: imageData,
      );
      
      _showSuccessMessage('บันทึก JPG สำเร็จ: $fileName');
      
    } catch (e) {
      print('Error saving JPG: $e');
      _showErrorMessage('เกิดข้อผิดพลาดในการบันทึก JPG: $e');
    } finally {
      setState(() => _isGeneratingFile = false);
    }
  }

  /// แปลง QR Code Widget เป็น Image Data
  Future<Uint8List> _captureQRAsImage() async {
    final RenderRepaintBoundary boundary = 
        _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// เรนเดอร์ข้อความเป็น PNG (fallback สำหรับ PDF เมื่อฟอนต์ไทยไม่พร้อมใน pdf)
  Future<Uint8List> _renderTextAsPng(String text, double fontSize, {bool bold = false, Color color = Colors.black}) async {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.transparent;
    final width = (tp.width + 4).ceilToDouble();
    final height = (tp.height + 4).ceilToDouble();
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
    tp.paint(canvas, const Offset(2, 2));
    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // บันทึกไฟล์: ใช้ SaveFileHelper (รองรับทุกแพลตฟอร์ม)

  /// ทำความสะอาดชื่อไฟล์
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// แสดงข้อความสำเร็จ
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// แสดงข้อความข้อผิดพลาด
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 4),
      ),
    );
  }
}

/// Widget ตัวอย่าง QR Code สำหรับแสดงระหว่างการพิมพ์ชื่อสนาม
class QRPreviewWidget extends StatelessWidget {
  final String courtName;
  final double size;

  const QRPreviewWidget({
    Key? key,
    required this.courtName,
    this.size = 100.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (courtName.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, color: Colors.grey[400], size: 40),
            SizedBox(height: 8),
            Text(
              'พิมพ์ชื่อสนาม\nเพื่อดู QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: courtName,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            courtName,
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}