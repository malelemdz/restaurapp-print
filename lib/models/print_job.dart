import 'dart:convert';

class PrintJob {
  final String id;
  final String type; // 'cliente', 'sushi', 'pizza'
  final Map<String, dynamic> data;
  final String timestamp;

  PrintJob({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
  });

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    // 1. Obtener la data cruda (prioridad 'contenido', fallback 'data')
    var rawData = json['contenido'] ?? json['data'];
    
    Map<String, dynamic> sourceData = {};

    // 2. Decodificar si es string
    if (rawData is String) {
      try {
        sourceData = jsonDecode(rawData);
      } catch (e) {
        print('Error decodificando contenido JSON: $e');
      }
    } else if (rawData is Map) {
      sourceData = Map<String, dynamic>.from(rawData);
    }

    // 3. Mapear al formato plano que espera el PdfGenerator
    // Estrategia: "Aplanar" la estructura compleja (info_pedido, totales) a llaves simples (fecha, total)
    Map<String, dynamic> flatData = {};

    try {
      // A. Mapear Info Pedido (Detalles)
      if (sourceData['info_pedido'] != null && sourceData['info_pedido']['detalles'] is List) {
        for (var det in sourceData['info_pedido']['detalles']) {
          String key = det['label'].toString().toLowerCase()
              .replaceAll(' ', '_') // 'Recibo No' -> 'recibo_no'
              .replaceAll(':', '');
          
          flatData[key] = det['value'];
          
          // Mapeos especificos para inconsistencias de nombres
          if (key == 'fecha') flatData['fecha'] = det['value'];
          if (key == 'hora') flatData['hora'] = det['value'];
          // Robust key matching (ignoring accents)
          if (key.contains('cliente')) flatData['cliente'] = det['value'];
          if (key.contains('servicio')) flatData['servicio'] = det['value'];
          if (key.contains('telef') || key.contains('movil') || key.contains('celular')) flatData['telefono'] = det['value']; 
          if (key.contains('direc') || key.contains('domicilio') || key.contains('ubicacion')) flatData['direccion'] = det['value'];
          
          // Mapear resumen de otras cocinas (dentro de detalles)
          if (key.contains('resumen') || key.contains('otra') || key.contains('pendiente')) {
             flatData['nota_otra_cocina'] = det['value'];
          }
        }
      }
      
      // Mapear aviso_otra_cocina (Hijo directo de info_pedido, SIBLING de detalles)
      if (sourceData['info_pedido'] != null && sourceData['info_pedido']['aviso_otra_cocina'] != null) {
        final aviso = sourceData['info_pedido']['aviso_otra_cocina'];
        if (aviso['mostrar'] == true && aviso['texto'] != null) {
          flatData['nota_otra_cocina'] = aviso['texto'];
        }
      }

      // B. Mapear Items
      if (sourceData['items'] != null && sourceData['items']['lista'] is List) {
        flatData['items'] = (sourceData['items']['lista'] as List).map((apiItem) {
          return {
            'cantidad': apiItem['cantidad'],
            'descripcion': apiItem['nombre'] + (apiItem['variante_nombre'] != null ? ' ${apiItem['variante_nombre']}' : ''),
            'precio_formateado': apiItem['precio_total_display'],
            'notas': apiItem['notas'], // Para cocina
            'es_nota': false, 
          };
        }).toList();
      }

      // C. Mapear Totales
      if (sourceData['totales'] != null && sourceData['totales']['lineas'] is List) {
        for (var line in sourceData['totales']['lineas']) {
          String label = line['label'].toString().toLowerCase();
          // Robust matching for accents
          if (label.contains('subtotal')) flatData['subtotal'] = line['value'];
          if (label.contains('propina')) flatData['propina'] = line['value'];
          if (label.contains('env') || label.contains('delivery') || label.contains('despacho')) flatData['costo_delivery'] = line['value'];
          if (label.contains('total') && line['es_total_final'] == true) flatData['total'] = line['value'];
        }
      }

      // D. Mapear Notas Generales (Pie de Pagina)
      if (sourceData['pie_pagina'] != null) {
        if (sourceData['pie_pagina']['notas_generales'] != null) {
          flatData['notas'] = sourceData['pie_pagina']['notas_generales'].toString();
        }
        if (sourceData['pie_pagina']['mensaje_final'] != null) {
          flatData['mensaje_final'] = sourceData['pie_pagina']['mensaje_final'].toString();
        }
      }
      
      // E. Mapear IDs y Extras (Cocina)
      if (sourceData['pedido_id'] != null) flatData['numero_pedido'] = sourceData['pedido_id'];
      if (json['pedido_id'] != null) flatData['numero_pedido'] = json['pedido_id']; // ID raiz tiene prioridad

      // Copiar cualquier otra llave directa por si acaso
      sourceData.forEach((k, v) {
        if (!flatData.containsKey(k)) flatData[k] = v;
      });

    } catch (e) {
      print('Error mapeando datos flatten: $e');
    }

    return PrintJob(
      id: json['id'].toString(),
      type: json['tipo_impresion'] ?? 'unknown',
      data: flatData,
      timestamp: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}
