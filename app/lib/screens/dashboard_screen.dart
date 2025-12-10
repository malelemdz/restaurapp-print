import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart'; // For exit
import 'dart:io' show Platform;
import '../services/print_service.dart';
import '../theme/app_theme.dart';
import 'config_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WindowListener, TrayListener {
  final PrintService _service = PrintService();
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isRunning = false;
  String _appVersion = '';
  
  // Tray settings
  bool _minimizeToTray = false;

  @override
  void initState() {
    super.initState();
    // Listen to status changes
    _service.statusStream.listen((status) {
      if (mounted) {
        setState(() => _isRunning = status);
        _updateTrayMenu();
      }
    });
    
    // Listen to logs
    _service.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log); // Append: Oldest at top, Newest at bottom
          if (_logs.length > 500) _logs.removeAt(0); // Keep max 500
        });

        // Auto-scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // Check initial state
    _isRunning = _service.isRunning;
    
    _loadAppVersion();
    _initTray();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _loadSettings();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _minimizeToTray = prefs.getBool('minimize_to_tray') ?? false;
      });
    }
  }

  Future<void> _initTray() async {
    await trayManager.setIcon(
      Platform.isMacOS ? 'assets/images/ico-menubar.png' : 'assets/images/ico-windows.png', 
    );
    await trayManager.setToolTip('RestaurApp Print');
    await _updateTrayMenu();
  }

  Future<void> _updateTrayMenu() async {
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Abrir RestaurApp Print',
        ),
        MenuItem.separator(),
        MenuItem(
          key: _isRunning ? 'stop_service' : 'start_service',
          label: _isRunning ? 'Detener Servicio' : 'Iniciar Servicio',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: 'Salir',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  // --- Window Listener ---
  @override
  void onWindowClose() async {
    // Reload settings just in case changed in Config
    final prefs = await SharedPreferences.getInstance();
    bool minimize = prefs.getBool('minimize_to_tray') ?? false;

    if (minimize) {
      await windowManager.hide();
    } else {
       bool shouldExit = await _showExitConfirmation();
       if (shouldExit) {
         await windowManager.destroy(); // Actually close
       }
       // If no, do nothing (event prevents close by default? wait, we need to ensure preventClose is managed)
       // Flutter window_manager onWindowClose is just a listener, usually we need to setQuitOnClose(false) for this to work as interceptor
       // Actually window_manager usually requires 'preventClose' to be set to true if we want to intercept. 
       // We'll update main.dart or init to setPreventClose(true) and handle destruction manually.
    }
  }

  // --- Tray Listener ---
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'start_service') {
      _service.start();
    } else if (menuItem.key == 'stop_service') {
      _service.stop();
    } else if (menuItem.key == 'exit_app') {
      _confirmExit();
    }
  }
  
  Future<void> _confirmExit() async {
    // We want to restore window to show dialog
    await windowManager.show();
    await windowManager.focus();
    
    if (await _showExitConfirmation()) {
       await windowManager.destroy();
       // exit(0); // Force exit if needed
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Salida'),
        content: const Text('¿Estás seguro de que deseas salir?\nEl servicio de impresión se detendrá.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Salir'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  void _toggleService() {
    if (_isRunning) {
      _service.stop();
      _showServiceToggleFeedback(false);
    } else {
      _service.start();
      _showServiceToggleFeedback(true);
    }
  }

  void _showServiceToggleFeedback(bool isStarting) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isStarting ? Icons.check_circle : Icons.pause_circle_filled, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              isStarting ? 'Servicio iniciado correctamente' : 'Servicio detenido',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: isStarting ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const ConfigScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              Platform.isMacOS ? 'assets/images/ico-title.png' : 'assets/images/ico-windows.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'Servicio de Impresión',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        titleSpacing: 24, // Explicit alignment
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Configuración',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Status Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // Aligned to 24
            color: _isRunning 
                ? AppTheme.success.withOpacity(0.1) 
                : AppTheme.error.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  _isRunning ? Icons.check_circle : Icons.pause_circle_filled,
                  size: 32,
                  color: _isRunning ? AppTheme.success : AppTheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRunning ? 'Servicio Activo' : 'Servicio Detenido',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _isRunning ? 'Monitoreando cola de impresión...' : 'Presiona Iniciar para comenzar',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleService,
                  icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(_isRunning ? 'DETENER' : 'INICIAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? AppTheme.error : AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Logs Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 15, 24, 5), // Aligned to 24
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Registro de Actividad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Limpiar'),
                  onPressed: () => setState(() => _logs.clear()),
                )
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // Aligned to 24
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
                color: Theme.of(context).cardColor,
              ),
              child: _logs.isEmpty 
                ? const Center(child: Text('No hay actividad reciente', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      // Simple syntax highlighting based on content
                      Color color = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
                      
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      
                      const Color warningDark = Color(0xFFFFD600); // Yellow A700
                      const Color warningLight = Color(0xFFEF6C00); // Orange 800

                      if (log.contains('Error')) {
                        color = isDark ? const Color(0xFFFF8A80) : Colors.red[800]!;
                      } else if (log.contains('completado')) {
                         color = isDark ? const Color(0xFF69F0AE) : Colors.green[800]!;
                      } else if (log.toLowerCase().contains('procesando') || 
                                 log.toLowerCase().contains('esperando') || 
                                 log.toLowerCase().contains('pendientes')) {
                         color = isDark ? warningDark : warningLight;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1), // Tighter logs
                        child: Text(
                          log, 
                          style: TextStyle(fontFamily: 'Courier', fontSize: 12, color: color),
                        ),
                      );
                    },
                  ),
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.only(bottom: 12, top: 2), // Lift text up
            alignment: Alignment.center,
            child: Text('RestaurApp Print v$_appVersion', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
