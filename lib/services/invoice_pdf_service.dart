// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/services.dart';
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;

// class InvoicePdfService {
//   static Future<File> generateInvoice({
//     required String appName,
//     required String customerName,
//     required String transactionId,
//     required String amount,
//     required DateTime date,
//     required String paymentStatus,
//   }) async {
//     final pdf = pw.Document();

//     // Load Logo Image
//     final ByteData imageData =
//         await rootBundle.load('assets/images/app_logo.png');
//     final Uint8List imageBytes = imageData.buffer.asUint8List();

//     final PdfColor primaryColor = PdfColor.fromInt(0xFFFFC107); // Yellow theme

//     pdf.addPage(
//       pw.Page(
//         pageFormat: PdfPageFormat.a4,
//         margin: const pw.EdgeInsets.all(32),
//         build: (pw.Context context) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               /// HEADER
//               pw.Row(
//                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                 children: [
//                   pw.Image(
//                     pw.MemoryImage(imageBytes),
//                     width: 80,
//                   ),
//                   pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.end,
//                     children: [
//                       pw.Text(
//                         "INVOICE",
//                         style: pw.TextStyle(
//                           fontSize: 24,
//                           fontWeight: pw.FontWeight.bold,
//                           color: primaryColor,
//                         ),
//                       ),
//                       pw.SizedBox(height: 4),
//                       pw.Text(
//                         DateFormat('dd MMM yyyy').format(date),
//                         style: const pw.TextStyle(fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),

//               pw.SizedBox(height: 30),

//               /// BILL TO
//               pw.Text(
//                 "Bill To:",
//                 style: pw.TextStyle(
//                   fontSize: 14,
//                   fontWeight: pw.FontWeight.bold,
//                 ),
//               ),
//               pw.SizedBox(height: 5),
//               pw.Text(customerName),
//               pw.SizedBox(height: 20),

//               /// TABLE
//               pw.Container(
//                 decoration: pw.BoxDecoration(
//                   border: pw.Border.all(color: PdfColors.grey300),
//                 ),
//                 child: pw.Table(
//                   border: pw.TableBorder.symmetric(
//                     inside: pw.BorderSide(color: PdfColors.grey300),
//                   ),
//                   children: [
//                     pw.TableRow(
//                       decoration: pw.BoxDecoration(color: primaryColor),
//                       children: [
//                         _tableCell("Description", isHeader: true),
//                         _tableCell("Transaction ID", isHeader: true),
//                         _tableCell("Amount", isHeader: true),
//                         _tableCell("Status", isHeader: true),
//                       ],
//                     ),
//                     pw.TableRow(
//                       children: [
//                         _tableCell("Subscription Payment"),
//                         _tableCell(transactionId),
//                         _tableCell("₹ $amount"),
//                         _tableCell(paymentStatus),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),

//               pw.Spacer(),

//               /// TOTAL
//               pw.Align(
//                 alignment: pw.Alignment.centerRight,
//                 child: pw.Container(
//                   padding: const pw.EdgeInsets.all(12),
//                   decoration: pw.BoxDecoration(
//                     color: primaryColor,
//                     borderRadius: pw.BorderRadius.circular(6),
//                   ),
//                   child: pw.Text(
//                     "Total: ₹ $amount",
//                     style: pw.TextStyle(
//                       color: PdfColors.white,
//                       fontSize: 16,
//                       fontWeight: pw.FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),

//               pw.SizedBox(height: 20),

//               pw.Center(
//                 child: pw.Text(
//                   "Thank you for your business!",
//                   style: pw.TextStyle(
//                     fontSize: 12,
//                     color: PdfColors.grey700,
//                   ),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );

//     final output = await getTemporaryDirectory();
//     final file = File("${output.path}/invoice_$transactionId.pdf");
//     await file.writeAsBytes(await pdf.save());

//     return file;
//   }

//   static pw.Widget _tableCell(String text, {bool isHeader = false}) {
//     return pw.Padding(
//       padding: const pw.EdgeInsets.all(8),
//       child: pw.Text(
//         text,
//         style: pw.TextStyle(
//           fontSize: 12,
//           fontWeight:
//               isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
//           color: isHeader ? PdfColors.white : PdfColors.black,
//         ),
//       ),
//     );
//   }
// }

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class InvoicePdfService {
  static Future<Uint8List> generateInvoice({
    required String appName,
    required String customerName,
    required String transactionId,
    required String amount,
    required DateTime date,
    required String paymentStatus,
  }) async {
    final pdf = pw.Document();

    final ByteData imageData =
        await rootBundle.load('assets/images/app_logo.png');
    final Uint8List imageBytes = imageData.buffer.asUint8List();

    final PdfColor primaryColor = PdfColor.fromInt(0xFFFFC107);

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(pw.MemoryImage(imageBytes), width: 70),
                  pw.Text(
                    "INVOICE",
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Text("Customer: $customerName"),
              pw.Text("Transaction ID: $transactionId"),
              pw.Text("Date: ${DateFormat('dd MMM yyyy').format(date)}"),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text("Subscription Payment"),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total: ₹ $amount",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Center(child: pw.Text("Thank you for your business!")),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}