import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/print_job.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  // Configuración de Espaciado Uniforme
  static const double kPaddingLine = 2.0;       // Interlineado general (items, datos, notas)
  static const double kPaddingSection = 4.0;    // Separación entre secciones y divisores
  static const double kDividerHeight = 2.0;     // Altura visual de la línea divisoria

  static Future<void> generateAndPrint(PrintJob job, Printer? printer) async {
    // DEBUG MODE: Guardar en archivo en lugar de imprimir
    try {
      final pdf = pw.Document();
      
      // Load Fonts
      final fontRegular = await rootBundle.load("assets/fonts/arialnarrow.ttf");
      final fontBold = await rootBundle.load("assets/fonts/arialnarrow_bold.ttf");
      final ttfRegular = pw.Font.ttf(fontRegular);
      final ttfBold = pw.Font.ttf(fontBold);

      // Build PDF content based on type
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(16), 
          build: (pw.Context context) {
            return pw.Theme(
              data: pw.ThemeData.withFont(
                base: ttfRegular,
                bold: ttfBold,
              ),
              child: pw.DefaultTextStyle(
                style: pw.TextStyle(
                  color: PdfColors.black, 
                  fontSize: 12,
                  font: ttfRegular,
                ),
                child: _buildContent(job, ttfRegular, ttfBold),
              ),
            );
          },
        ),
      );

      // Enviar a impresora real
      if (printer != null) {
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'RestaurApp Ticket ${job.id}',
        );
      } else {
        print('⚠️ No se seleccionó impresora para este trabajo (${job.type}). Omitiendo impresión.');
      }
      
    } catch (e) {
      print('Error generando PDF: $e');
      rethrow;
    }
  }

  static pw.Widget _buildContent(PrintJob job, pw.Font font, pw.Font fontBold) {
    if (job.type == 'cliente') {
      return _buildReciboCliente(job.data);
    } else {
      return _buildComandaCocina(job.data, job.type); // sushi or pizza
    }
  }

  // === TICKET CLIENTE ===
  static pw.Widget _buildReciboCliente(Map<String, dynamic> data) {
    // Extract variables properly before building widget tree
    final phone = data['telefono'] ?? data['teléfono'];
    final address = data['direccion'] ?? data['dirección'];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Center(child: pw.Text('SUSHI & PIZZA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 5),
        pw.Center(child: pw.Text('Amazona Sushi Nikkei', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text('+56 9 2607 5590', style: const pw.TextStyle(fontSize: 10))),
        pw.Center(child: pw.Text('Pizzería Raúl Bravo', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text('+56 9 4192 4833', style: const pw.TextStyle(fontSize: 10))),
        pw.SizedBox(height: 5),
        pw.Center(child: pw.Text('Juan Martínez 1898, Iquique Chile', style: const pw.TextStyle(fontSize: 12))),
        pw.SizedBox(height: 2), // Extra padding for header as requested
        
        // SEPARATOR: HEADER -> INFO
        pw.SizedBox(height: kPaddingSection),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: kDividerHeight),
        pw.SizedBox(height: kPaddingSection),

        // Info
        _buildInfoRow('Fecha: ${_getCurrentDate()}', 'Hora Impresión: ${_getCurrentTime()}'),
        _buildInfoRow('Recibo No:', data['recibo_no'] ?? ''),
        _buildInfoRow('Servicio:', data['servicio'] ?? 'General'),
        _buildInfoRow('Cliente:', data['cliente'] ?? 'Cliente General'),
        
        if (phone != null && phone.toString().isNotEmpty)
          _buildInfoRow('Teléfono:', phone),
          
        if (address != null && address.toString().isNotEmpty)
           pw.Padding(
             padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
             child: pw.Row(
               crossAxisAlignment: pw.CrossAxisAlignment.start,
               children: [
                 pw.Text('Dirección:'),
                 pw.SizedBox(width: 10),
                 pw.Expanded(
                   child: pw.Text(
                     address, 
                     textAlign: pw.TextAlign.right,
                   )
                 ),
               ],
             )
           ),

        // SEPARATOR: HEADER/INFO -> ITEMS
        pw.SizedBox(height: kPaddingSection),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: kDividerHeight),
        pw.SizedBox(height: kPaddingSection),
        
        // Items Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Descripción', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Importe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 5), // Keep a bit more space for header title

        // Items List
        if (data['items'] != null)
          for (var item in data['items'])
            _buildItemRow(item),

        // SEPARATOR: ITEMS -> TOTALS
        pw.SizedBox(height: kPaddingSection),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: kDividerHeight),
        pw.SizedBox(height: kPaddingSection),

        // Totals
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
          child: _buildTotalRow('Subtotal:', data['subtotal'] ?? '')
        ),
        
        if (data['propina'] != null && data['propina'].toString().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
            child: _buildTotalRow('Propina:', data['propina'])
          ),
            
        if (data['costo_delivery'] != null && data['costo_delivery'].toString().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
            child: _buildTotalRow('Delivery:', data['costo_delivery'])
          ),

        if (data['total'] != null)
           _buildTotalRow('TOTAL', data['total'], isBold: true, fontSize: 16),
        
        // SECCION NOTAS GENERALES
        if (data['notas'] != null && data['notas'].toString().isNotEmpty) ...[
           // SEPARATOR: TOTALS -> NOTES
           pw.SizedBox(height: kPaddingSection),
           pw.Divider(borderStyle: pw.BorderStyle.dashed, height: kDividerHeight),
           pw.SizedBox(height: kPaddingSection),
           
           pw.Text("Notas:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
           pw.Text(data['notas']),
        ],

        // SEPARATOR: NOTES/TOTALS -> FOOTER
        pw.SizedBox(height: kPaddingSection),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: kDividerHeight),
        pw.SizedBox(height: kPaddingSection),

        // Footer
        pw.Center(child: pw.Text(data['mensaje_final'] ?? '¡Gracias por su compra!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
      ],
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value),
        ],
      ),
    );
  }

  static pw.Widget _buildItemRow(Map<String, dynamic> item) {
    final bool isNota = item['es_nota'] == true || item['cantidad'] == 0;
    final List<dynamic> notas = item['notas'] is List ? item['notas'] : [];
    
    // REDUCIDO: Ancho fijo para la columna de cantidad ("1x") más ajustado.
    // Antes 22, ahora 18 para acercarlo al nombre.
    const double colCantidadWidth = 18;

    return pw.Column(
      children: [
        // Main Item Row
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
          child: pw.Row(
           crossAxisAlignment: pw.CrossAxisAlignment.start,
           children: [
             // Columna 1: Cantidad
             if (!isNota)
               pw.SizedBox(
                 width: colCantidadWidth,
                 child: pw.Text('${item['cantidad']}x', style: const pw.TextStyle(fontSize: 12)),
               )
             else
               // Si es un item tipo nota, mantenemos la sangría vacía
               pw.SizedBox(width: colCantidadWidth),

             // Columna 2: Descripción (Expanded para que multilínea respete la sangría)
             pw.Expanded(
               child: pw.Text(
                 item['descripcion'],
                 style: const pw.TextStyle(fontSize: 12),
               ),
             ),
             
             // Separación visual con el precio
             pw.SizedBox(width: 10),

             // Columna 3: Precio
             pw.Text(
               item['precio_formateado'] ?? '',
               style: const pw.TextStyle(fontSize: 12),
             ),
           ],
          ),
        ),

        // Notes Rows (Client Side)
        if (notas.isNotEmpty)
          for (var nota in notas)
            _buildItemNoteRow(nota, indent: colCantidadWidth),
      ]
    );
  }

  static pw.Widget _buildItemNoteRow(dynamic nota, {required double indent}) {
    String text = '';
    String price = '';

    if (nota is Map) {
      text = nota['texto'] ?? '';
      price = nota['precio_extra_display'] ?? '';
    } else {
      text = nota.toString();
    }

    if (text.isEmpty) return pw.Container();

    // Fix doble signo más: Verificar si el string ya trae el '+'
    if (price.isNotEmpty && !price.startsWith('+')) {
      price = '+$price';
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Sangría para alinear con la descripción del producto
          pw.SizedBox(width: indent),

          pw.Expanded(
            child: pw.Text(
              '($text)',
              style: const pw.TextStyle(fontSize: 12), 
            ),
          ),
          if (price.isNotEmpty) ...[
             pw.SizedBox(width: 10),
             pw.Text(
               price,
               style: const pw.TextStyle(fontSize: 12),
             ),
          ]
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false, double fontSize = 12}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : null)),
        pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : null)),
      ],
    );
  }


  // === TICKET COCINA (SUSHI / PIZZA) ===
  static pw.Widget _buildComandaCocina(Map<String, dynamic> data, String type) {
    final title = type == 'pizza' ? 'COCINA PIZZA' : 'COCINA SUSHI';
    
    // Info logic moved up
    String pedidoNum = data['recibo_no'] ?? data['numero_pedido'] ?? '';
    try {
      pedidoNum = int.parse(pedidoNum.toString()).toString();
    } catch (_) {}

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Center(child: pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 5), // Reducido de 20 a 5

        pw.Center(child: pw.Text('PEDIDO #$pedidoNum - ${data['servicio'] ?? ''}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text('Cliente: ${data['cliente'] ?? ''}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text('Hora Impresión: ${_getCurrentTime()}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: kPaddingLine),
          child: pw.Center(
            child: pw.Text(
              (data['nota_otra_cocina'] != null && data['nota_otra_cocina'].toString().isNotEmpty) 
                  ? data['nota_otra_cocina'] 
                  : 'Solo productos de esta cocina',
              style: const pw.TextStyle(fontSize: 12)
            )
          ),
        ),

        // SEPARATOR: HEADER -> ITEMS
        pw.SizedBox(height: kPaddingSection),
        pw.Divider(borderStyle: pw.BorderStyle.dashed, height: kDividerHeight),
        pw.SizedBox(height: kPaddingSection),

        // Items (Letra Grande)
        if (data['items'] != null)
          for (var item in data['items'])
            _buildItemCocina(item),

        // Notas Generales
        if (data['notas'] != null && data['notas'].toString().isNotEmpty) ...[
          // SEPARATOR: ITEMS -> NOTES
          pw.SizedBox(height: kPaddingSection),
          pw.Divider(borderStyle: pw.BorderStyle.dashed, height: kDividerHeight),
          pw.SizedBox(height: kPaddingSection),
          
          pw.Text('Notas del Pedido:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)), // Título grande sin espacio inicial
          pw.Text(data['notas'] ?? '', style: const pw.TextStyle(fontSize: 14)), // Contenido grande
        ],
      ],
    );
  }

  static pw.Widget _buildItemCocina(Map<String, dynamic> item) {
    // Usar 'kPaddingLine' para mantener consistencia de interlineado
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${item['cantidad']}x ${item['descripcion']}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          if (item['notas'] != null && (item['notas'] as List).isNotEmpty)
            for (var nota in item['notas'])
               _buildNotaCocina(nota),
        ],
      ),
    );
  }

  static pw.Widget _buildNotaCocina(dynamic nota) {
    String text = '';
    if (nota is Map) {
      text = nota['texto'] ?? '';
    } else {
      text = nota.toString();
    }
    
    if (text.isEmpty) return pw.Container();

    return pw.Padding(
       padding: const pw.EdgeInsets.only(bottom: kPaddingLine),
       child: pw.Row(
         crossAxisAlignment: pw.CrossAxisAlignment.start,
         children: [
           pw.SizedBox(width: 10), // Indentación ligera
           pw.Expanded(child: pw.Text('• $text', style: const pw.TextStyle(fontSize: 14))),
         ],
       ) 
    );
  }

  static String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  static String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
}
