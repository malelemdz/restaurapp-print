import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform, Process;
import '../theme/app_theme.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _domainController = TextEditingController();
  List<Printer> _printers = [];
  Printer? _selectedPrinterCliente;
  Printer? _selectedPrinterSushi;
  Printer? _selectedPrinterPizza;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDomainLocked = true; // Default locked for safety
  
  // System Settings
  bool _startOnBoot = false;
  bool _minimizeToTray = false;
  bool _autoStartService = true; // Default true per user preference for smart behavior

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await _refreshPrinters();
      
      final prefs = await SharedPreferences.getInstance();
      final savedDomain = prefs.getString('domain') ?? '';
      final savedCliente = prefs.getString('printer_cliente');
      final savedSushi = prefs.getString('printer_sushi');
      final savedPizza = prefs.getString('printer_pizza');

      _domainController.text = savedDomain;
       
      bool isEnabled = false;
      try {
        isEnabled = await LaunchAtStartup.instance.isEnabled();
      } catch (_) {}

      if (mounted) {
        setState(() {
          if (savedCliente != null) _selectedPrinterCliente = _findPrinterByUrl(_printers, savedCliente);
          if (savedSushi != null) _selectedPrinterSushi = _findPrinterByUrl(_printers, savedSushi);
          if (savedPizza != null) _selectedPrinterPizza = _findPrinterByUrl(_printers, savedPizza);

          // Load System Settings
          _minimizeToTray = prefs.getBool('minimize_to_tray') ?? false;
          _autoStartService = prefs.getBool('auto_start_service') ?? true;
          // Hybrid approach: Load pref, fallback to system check if pref missing
          _startOnBoot = prefs.getBool('start_on_boot') ?? isEnabled;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshPrinters() async {
    final printers = await Printing.listPrinters();
    if (mounted) {
      setState(() {
        _printers = printers;
        // Re-validate selections to prevent "not found" errors in Dropdown
        if (_selectedPrinterCliente != null) {
          _selectedPrinterCliente = _findPrinterByUrl(printers, _selectedPrinterCliente!.url);
        }
        if (_selectedPrinterSushi != null) {
          _selectedPrinterSushi = _findPrinterByUrl(printers, _selectedPrinterSushi!.url);
        }
        if (_selectedPrinterPizza != null) {
          _selectedPrinterPizza = _findPrinterByUrl(printers, _selectedPrinterPizza!.url);
        }
      });
    }
  }

  Printer? _findPrinterByUrl(List<Printer> list, String url) {
    try {
      return list.firstWhere((p) => p.url == url);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveSettings() async {
    if (_domainController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Por favor ingresa un dominio válido', style: TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    
    // Sanitize domain
    String cleanDomain = _domainController.text.trim()
        .replaceAll('https://', '')
        .replaceAll('http://', '');
    if (cleanDomain.endsWith('/')) {
      cleanDomain = cleanDomain.substring(0, cleanDomain.length - 1);
    }
    _domainController.text = cleanDomain; // Visual update

    await prefs.setString('domain', cleanDomain);
    
    if (_selectedPrinterCliente != null) {
      await prefs.setString('printer_cliente', _selectedPrinterCliente!.url);
    } else {
      await prefs.remove('printer_cliente');
    }

    if (_selectedPrinterSushi != null) {
      await prefs.setString('printer_sushi', _selectedPrinterSushi!.url);
    } else {
      await prefs.remove('printer_sushi');
    }

    if (_selectedPrinterPizza != null) {
      await prefs.setString('printer_pizza', _selectedPrinterPizza!.url);
    } else {
      await prefs.remove('printer_pizza');
    }

    // Save System Settings
    await prefs.setBool('minimize_to_tray', _minimizeToTray);
    await prefs.setBool('auto_start_service', _autoStartService);
    await prefs.setBool('start_on_boot', _startOnBoot);
    
    // Configure Launch at Startup
    try {
      if (_startOnBoot) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
    } catch (_) {
      // Ignore if plugin missing or errored
    }
    
    // Reset loading FIRST
    if (mounted) setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Configuración guardada correctamente', style: TextStyle(color: Colors.white)),
            ],
          ),
          backgroundColor: AppTheme.success, 
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // Return to dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Atrás',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        titleSpacing: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      'GUARDAR',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760), // Widened for 2-column layout
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12), // Comfortable padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildDomainSection()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSystemSection()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12), 
                    _buildPrintersSection(),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildDomainSection() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: isLight 
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ) 
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Standardized to 16 to match other sections
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [ // ...
            // Row 1: Icon and Title
            Row(
              children: [
                const Icon(Icons.cloud_queue, color: AppTheme.primaryOrange, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Conectividad',
                  style: TextStyle(
                    fontSize: 13, // Compact header
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).textTheme.titleLarge?.color
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Increased to 20 for better separation

            // Row 2: Input and Action Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _domainController,
                    enabled: !_isDomainLocked, // Completely disables interaction
                    style: TextStyle(color: _isDomainLocked ? Colors.grey : null),
                    decoration: const InputDecoration(
                      labelText: 'Dominio del Servidor',
                      hintText: 'ej: restaurapp.malelemdz.com',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Thinner Input
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 0.0), // Align with standard input height
                    child: IconButton(
                      iconSize: 20,
                      constraints: const BoxConstraints(), // Compact button
                      padding: const EdgeInsets.all(8),
                      onPressed: () {
                      if (!_isDomainLocked) {
                        // Locking: Sanitize input
                         String cleanDomain = _domainController.text.trim()
                            .replaceAll('https://', '')
                            .replaceAll('http://', '');
                        if (cleanDomain.endsWith('/')) {
                          cleanDomain = cleanDomain.substring(0, cleanDomain.length - 1);
                        }
                        _domainController.text = cleanDomain;
                      }
                      setState(() => _isDomainLocked = !_isDomainLocked);
                    },
                    icon: Icon(
                      _isDomainLocked ? Icons.lock_outline : Icons.edit,
                      color: _isDomainLocked ? Colors.green : AppTheme.primaryOrange,
                    ),
                    tooltip: _isDomainLocked ? 'Desbloquear para editar' : 'Bloquear edición',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12), // Increased from 6

            // Row 3: Helper Text
            Text(
              'Ingresa solo el dominio, sin https:// ni rutas adicionales.\nEjemplo: midominio.com',
              style: TextStyle(
                fontSize: 11, // Increased slightly for readability
                color: Theme.of(context).textTheme.bodySmall?.color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSwitch(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        SizedBox(
          height: 24, // Force compact height
          child: Transform.scale(
            scale: 0.7, // Make switch look thinner/smaller
            child: Switch(
              value: value, 
              onChanged: onChanged,
              activeColor: AppTheme.primaryOrange,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSystemSection() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: isLight 
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ) 
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                const Icon(Icons.desktop_windows, color: AppTheme.primaryOrange, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Sistema',
                  style: TextStyle(
                    fontSize: 14, // Compact header
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).textTheme.titleLarge?.color
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 10), // Reduced from 6 + SwitchListTile padding
            
            // Custom Compact Switch Rows
            _buildCompactSwitch('Iniciar servicio al abrir', _autoStartService, (v) => setState(() => _autoStartService = v)),
            const SizedBox(height: 8),
            _buildCompactSwitch('Iniciar al arrancar sistema', _startOnBoot, (v) {
                 if (Platform.isMacOS) {
                  _showMacOsAutoStartDialog(v);
                } else {
                  setState(() => _startOnBoot = v);
                }
            }),
            const SizedBox(height: 8),
            _buildCompactSwitch('Minimizar a bandeja al cerrar', _minimizeToTray, (v) => setState(() => _minimizeToTray = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintersSection() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: isLight 
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ) 
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Comfortable card padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print, color: AppTheme.primaryOrange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Mapeo de Impresoras',
                      style: TextStyle(
                        fontSize: 14, // Compact header
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    await _refreshPrinters();
                    setState(() => _isLoading = false);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refrescar'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            if (_printers.isEmpty)
              Container(
                 padding: const EdgeInsets.all(12),
                 margin: const EdgeInsets.only(top: 15, bottom: 5),
                 decoration: BoxDecoration(
                   color: AppTheme.warning.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: AppTheme.warning.withOpacity(0.3))
                 ),
                 child: const Row(children: [Icon(Icons.warning_amber, color: AppTheme.warning), SizedBox(width: 10), Expanded(child: Text('No se detectaron impresoras instaladas.'))])
              ),
            const SizedBox(height: 8),
            _buildPrinterDropdown(
              'Recibo Cliente (Boleta)', 
              _selectedPrinterCliente, 
              (val) => setState(() => _selectedPrinterCliente = val)
            ),
            const SizedBox(height: 6),
            _buildPrinterDropdown(
              'Comanda Sushi', 
              _selectedPrinterSushi, 
              (val) => setState(() => _selectedPrinterSushi = val)
            ),
            const SizedBox(height: 6),
            _buildPrinterDropdown(
              'Comanda Pizza', 
              _selectedPrinterPizza, 
              (val) => setState(() => _selectedPrinterPizza = val)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterDropdown(String label, Printer? value, Function(Printer?) onChanged) {
    // Ensure value exists in list or is null
    Printer? safeValue;
    if (value != null) {
      try {
        safeValue = _printers.firstWhere((p) => p.url == value.url);
      } catch (e) {
        safeValue = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11, // Smaller label
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)
          )
        ),
        const SizedBox(height: 2),
        LayoutBuilder(
          builder: (context, constraints) {
              return DropdownMenu<Printer?>(
                initialSelection: safeValue,
                width: constraints.maxWidth,
                menuHeight: 200, // Constraint height to avoid overflow
                requestFocusOnTap: false,
              enableFilter: false,
              textStyle: TextStyle(
                 color: Theme.of(context).textTheme.bodyLarge?.color,
                 fontSize: 14,
              ),
               inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                filled: true,
                isDense: true, // Super compact
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
              trailingIcon: const Icon(Icons.arrow_drop_down),
              selectedTrailingIcon: const Icon(Icons.arrow_drop_up),
              onSelected: onChanged,
              dropdownMenuEntries: [
                const DropdownMenuEntry<Printer?>(
                  value: null,
                  label: 'Ninguna (Desactivado)',
                  leadingIcon: Icon(Icons.block, size: 18, color: Colors.grey),
                ),
                ..._printers.map((p) => DropdownMenuEntry<Printer?>(
                  value: p,
                  label: p.name,
                  leadingIcon: const Icon(Icons.print, size: 18, color: AppTheme.primaryOrange),
                )),
              ],
            );
          }
        ),
      ],
    );
  }


  Future<void> _showMacOsAutoStartDialog(bool enable) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(enable ? 'Activar Inicio Automático' : 'Desactivar Inicio Automático'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('En macOS, esta opción debe configurarse manualmente. Sigue estos pasos:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (enable) ...[
              const Text('1. Ve a Configuración del Sistema > General > Items de inicio de sesión.'),
              const SizedBox(height: 6),
              const Text('2. En la sección "Abrir al iniciar sesión", pulsa el botón (+).'),
              const SizedBox(height: 6),
              const Text('3. Busca y selecciona la aplicación RestaurApp Print.'),
            ] else ...[
              const Text('1. Ve a Configuración del Sistema > General > Items de inicio de sesión.'),
              const SizedBox(height: 6),
              const Text('2. Selecciona "RestaurApp Print" de la lista.'),
              const SizedBox(height: 6),
              const Text('3. Pulsa el botón (-) para quitarla.'),
            ],
            const SizedBox(height: 16),
            const Text('Una vez hecho esto, confirma abajo para actualizar el estado en la app.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () {
               // Deep link to macOS Login Items Settings
               // Attempt modern URL scheme first
               Process.run('open', ['x-apple.systempreferences:com.apple.LoginItems-Settings.extension']);
            },
            child: const Text('Abrir Configuración'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _startOnBoot = enable);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: Text(enable ? 'Listo, ya lo agregué' : 'Listo, ya lo quité'),
          ),
        ],
      ),
    );
  }
}
