import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/print_job.dart';
import 'pdf_generator_service.dart';

class PrintService {
  // Singleton pattern
  static final PrintService _instance = PrintService._internal();
  factory PrintService() => _instance;
  PrintService._internal();

  final Logger _logger = Logger();
  Timer? _timer;
  bool _isRunning = false;
  String? _domain;
  
  // Stream for logs
  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  // Stream for running status
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  bool get isRunning => _isRunning;

  void _log(String message) {
    _logger.i(message);
    // Format with timestamp
    final time = DateTime.now().toIso8601String().substring(11, 19);
    _logController.add('[$time] $message');
  }

  void stop() {
    _timer?.cancel();
    _isRunning = false;
    _statusController.add(false);
    _log('Servicio detenido.');
  }

  Future<void> start() async {
    if (_isRunning) return;

    final prefs = await SharedPreferences.getInstance();
    _domain = prefs.getString('domain');

    if (_domain == null || _domain!.isEmpty) {
      _log('Error: Dominio no configurado. No se puede iniciar el servicio.');
      return;
    }

    _isRunning = true;
    _statusController.add(true);
    _log('Servicio de impresión iniciado');
    _log('Esperando impresión...');
    
    // Initial poll immediately
    _poll();
    
    // Schedule periodic polling every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _poll();
    });
  }

  Future<void> _poll() async {
    try {
      final url = Uri.parse('https://$_domain/backend/public/api-servicio-impresion.php?action=get_pending');
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        
        if (body is List) {
          // Legacy support or direct list
          final jobs = body.map((item) => PrintJob.fromJson(item)).toList();
          _processJobsList(jobs);
        } else if (body is Map) {
          if (body['success'] == true && body['data'] is List) {
             // New structure support
             final List<dynamic> data = body['data'];
             // DEBUG: Log the first item's data field to see what's coming
             if (data.isNotEmpty) {
               
             }
             
             final jobs = data.map((item) => PrintJob.fromJson(item)).toList();
             _processJobsList(jobs);
          } else if (body['error'] != null) {
             _log('Error Remoto: ${body['error']}');
          } else {
             _log('Respuesta inesperada: Estructura JSON no reconocida.');
          }
        }
      } else {
        _log('Error del Servidor: HTTP ${response.statusCode}');
        if (response.statusCode == 500) {
           _log('Revisa los logs de error de PHP en el servidor.');
        }
      }
    } catch (e) {
       _log('Error de conexión: $e');
    }
  }

  Future<void> _processJobsList(List<PrintJob> jobs) async {
    if (jobs.isNotEmpty) {
      if (jobs.length == 1) {
        _log('Se encontró 1 impresión pendiente');
      } else {
        _log('Se encontraron ${jobs.length} impresiones pendientes');
      }
      for (var job in jobs) {
        await _processJob(job);
      }
      _log('Esperando impresión...');
    } 
  }

  Future<void> _processJob(PrintJob job) async {
    // Determine friendly label
    String typeLabel = job.type; // default
    if (job.type == 'cliente') typeLabel = 'Recibo de Cliente';
    if (job.type == 'sushi') typeLabel = 'Comanda Sushi';
    if (job.type == 'pizza') typeLabel = 'Comanda Pizza';
    
    String pedidoId = job.data['numero_pedido']?.toString() ?? job.data['recibo_no'] ?? '???';
    // Remove leading zeros for log (just in case)
    try {
      pedidoId = int.parse(pedidoId.toString()).toString();
    } catch (_) {}

    _log('Impresión de Pedido ID $pedidoId ($typeLabel) imprimiendo...');
    

    try {
      final prefs = await SharedPreferences.getInstance();
      String? printerUrl;

      // Determine correct printer based on job type
      if (job.type == 'cliente') {
        printerUrl = prefs.getString('printer_cliente');
      } else if (job.type == 'sushi') {
        printerUrl = prefs.getString('printer_sushi');
      } else if (job.type == 'pizza') {
        printerUrl = prefs.getString('printer_pizza');
      }

      if (printerUrl == null || printerUrl.isEmpty) {
        _log('Error: Impresora no configurada para $typeLabel (ID $pedidoId). Omitiendo.');
        // We might want to mark it as completed or error in backend to avoid infinite loop
        // For now, retry later
        return;
      }

      // Find the printer object
      final printers = await Printing.listPrinters();
      Printer? targetPrinter;
      try {
        targetPrinter = printers.firstWhere((p) => p.url == printerUrl);
      } catch (e) {
        _log('Error: Impresora no encontrada en el sistema: $printerUrl');
        return;
      }

      // Execute Print
      await PdfGeneratorService.generateAndPrint(job, targetPrinter);
      
      // Mark as completed in backend
      await _markAsCompleted(job.id);
      _log('Impresión de Pedido ID $pedidoId ($typeLabel) completada exitosamente');
      
    } catch (e) {
      _log('Error procesando trabajo #${job.id}: $e');
    }
  }

  Future<void> _markAsCompleted(String jobId) async {
    try {
      final url = Uri.parse('https://$_domain/backend/public/api-servicio-impresion.php');
      final response = await http.post(
        url,
        body: {
          'action': 'mark_completed',
          'id': jobId,
        },
      );
      if (response.statusCode == 200) {
        // Silent success or debug only
      } else {
        _log('Error marcando completado (HTTP ${response.statusCode})');
      }
    } catch (e) {
      _log('Error marcando completado #${jobId}: $e');
    }
  }


}
