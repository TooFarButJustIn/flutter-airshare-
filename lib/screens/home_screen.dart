import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/network_service.dart';
import '../services/file_service.dart';
import '../services/transfer_service.dart';
import '../models/device_model.dart';
import '../widgets/device_card.dart';
import '../widgets/file_preview_card.dart';
import '../widgets/transfer_progress_card.dart';
import '../widgets/animated_background.dart';
import '../utils/network_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  int _selectedIndex = 0;
  String? _currentWifiName;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    try {
      // Get current WiFi info
      _currentWifiName = await NetworkUtils.getWifiName();

      // Initialize services
      final fileService = context.read<FileService>();
      final networkService = context.read<NetworkService>();
      final transferService = context.read<TransferService>();

      await fileService.initialize();
      await transferService.initialize(fileService.downloadDirectory ?? '');
      await transferService.startReceiveServer(NetworkService.TRANSFER_PORT);
      await networkService.startDiscoverable();

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint('App initialization error: $e');
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
              ],
            ),
          ),
          child: SafeArea(
            child: _isInitializing
                ? _buildLoadingScreen()
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _buildHeader(),
                        Expanded(child: _buildBody()),
                        _buildBottomNavigation(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.swap_horiz,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Initializing AirShare...',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up network services',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AirShare',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Consumer<NetworkService>(
                      builder: (context, networkService, _) {
                        return Text(
                          networkService.isDiscoverable
                              ? 'Discoverable as "${networkService.deviceName}"'
                              : 'Hidden from other devices',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Consumer<NetworkService>(
                builder: (context, networkService, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed: () => _toggleDiscoverable(networkService),
                      icon: Icon(
                        networkService.isDiscoverable ? Icons.visibility : Icons.visibility_off,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: networkService.isDiscoverable ? 'Hide from devices' : 'Make discoverable',
                    ),
                  );
                },
              ),
            ],
          ),
          if (_currentWifiName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _currentWifiName!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDiscoveryTab();
      case 1:
        return _buildFilesTab();
      case 2:
        return _buildTransfersTab();
      default:
        return _buildDiscoveryTab();
    }
  }

  Widget _buildDiscoveryTab() {
    return Consumer<NetworkService>(
      builder: (context, networkService, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDiscoveryToggle(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nearby Devices',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (networkService.isDiscovering)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${networkService.discoveredDevices.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: networkService.discoveredDevices.isEmpty
                    ? _buildEmptyDevicesState(networkService.isDiscovering)
                    : _buildDevicesList(networkService.discoveredDevices),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoveryToggle() {
    return Consumer<NetworkService>(
      builder: (context, networkService, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    networkService.isDiscovering ? Icons.radar : Icons.search,
                    key: ValueKey(networkService.isDiscovering),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      networkService.isDiscovering ? 'Scanning...' : 'Scan for devices',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      networkService.isDiscovering
                          ? '${networkService.discoveredDevices.length} devices found'
                          : 'Find devices to share files with',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: networkService.isDiscovering,
                onChanged: (value) => _toggleDiscovery(networkService, value),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyDevicesState(bool isScanning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: isScanning
                ? ScaleTransition(
                    key: const ValueKey('scanning'),
                    scale: _pulseAnimation,
                    child: Icon(
                      Icons.radar,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                    ),
                  )
                : Icon(
                    key: const ValueKey('empty'),
                    Icons.devices,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? 'Searching for devices...' : 'No devices found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isScanning
                ? 'Make sure other devices have AirShare open'
                : 'Make sure both devices are on the same WiFi\nand have discovery enabled',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList(List<Device> devices) {
    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              index * 0.1,
              1.0,
              curve: Curves.easeOut,
            ),
          )),
          child: DeviceCard(
            device: devices[index],
            onTap: () => _selectDevice(devices[index]),
          ),
        );
      },
    );
  }

  Widget _buildFilesTab() {
    return Consumer<FileService>(
      builder: (context, fileService, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selected Files',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (fileService.selectedFiles.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showClearFilesDialog(fileService),
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
              if (fileService.selectedFiles.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${fileService.selectedFiles.length} files • ${fileService.totalSizeFormatted}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: fileService.selectedFiles.isEmpty
                    ? _buildEmptyFilesState()
                    : _buildFilesList(fileService.selectedFiles),
              ),
              _buildFileActions(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyFilesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.file_copy_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No files selected',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose files to share with other devices',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '👇 Use the buttons below to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList(List<FileItem> files) {
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              index * 0.1,
              1.0,
              curve: Curves.easeOut,
            ),
          )),
          child: FilePreviewCard(
            file: files[index],
            onRemove: () => context.read<FileService>().removeFile(index),
          ),
        );
      },
    );
  }

  Widget _buildFileActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => context.read<FileService>().pickFiles(),
              icon: const Icon(Icons.attach_file),
              label: const Text('Documents'),
              style: _getActionButtonStyle(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => context.read<FileService>().pickImages(),
              icon: const Icon(Icons.image),
              label: const Text('Photos'),
              style: _getActionButtonStyle(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => context.read<FileService>().pickVideos(),
              icon: const Icon(Icons.videocam),
              label: const Text('Videos'),
              style: _getActionButtonStyle(),
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _getActionButtonStyle() {
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 12),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      side: BorderSide(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
      ),
    );
  }

  Widget _buildTransfersTab() {
    return Consumer<TransferService>(
      builder: (context, transferService, _) {
        final transfers = transferService.activeTransfers.values.toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transfers',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (transfers.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${transfers.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _showClearTransfersDialog(transferService),
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: transfers.isEmpty
                    ? _buildEmptyTransfersState()
                    : _buildTransfersList(transfers),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyTransfersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.swap_horiz,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No active transfers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'File transfers will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransfersList(List<TransferProgress> transfers) {
    return ListView.separated(
      itemCount: transfers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              index * 0.1,
              1.0,
              curve: Curves.easeOut,
            ),
          )),
          child: TransferProgressCard(
            progress: transfers[index],
            onCancel: () => _cancelTransfer(transfers[index]),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildNavItem(0, Icons.radar, 'Discover'),
          _buildNavItem(1, Icons.folder, 'Files'),
          _buildNavItem(2, Icons.swap_horiz, 'Transfers'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Event Handlers
  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleDiscoverable(NetworkService networkService) {
    if (networkService.isDiscoverable) {
      networkService.stopDiscoverable();
    } else {
      networkService.startDiscoverable();
    }
  }

  void _toggleDiscovery(NetworkService networkService, bool value) {
    if (value) {
      networkService.startDiscovery();
    } else {
      networkService.stopDiscovery();
    }
  }

  void _selectDevice(Device device) {
    final fileService = context.read<FileService>();
    if (fileService.selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select files first'),
          action: SnackBarAction(
            label: 'Select Files',
            onPressed: () => setState(() => _selectedIndex = 1),
          ),
        ),
      );
      return;
    }
    _showSendConfirmationDialog(device, fileService);
  }

  void _showSendConfirmationDialog(Device device, FileService fileService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.send,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Send to ${device.name}?'),
            ),
          ],
        ),
        content: Text(
          'Send ${fileService.selectedFiles.length} files (${fileService.totalSizeFormatted}) to ${device.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTransfer(device, fileService.selectedFiles);
              setState(() => _selectedIndex = 2);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _startTransfer(Device device, List<FileItem> files) {
    final transferService = context.read<TransferService>();
    transferService.sendFiles(files, device).listen(
      (progress) {
        // Progress updates handled by TransferService notifyListeners
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $error')),
        );
      },
      onDone: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer completed!')),
        );
      },
    );
  }

  void _cancelTransfer(TransferProgress progress) {
    context.read<TransferService>().cancelTransfer(progress.fileId);
  }

  void _showClearFilesDialog(FileService fileService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all files?'),
        content: const Text('This will remove all selected files from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              fileService.clearFiles();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearTransfersDialog(TransferService transferService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear completed transfers?'),
        content: const Text('This will remove all completed, failed, and cancelled transfers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              transferService.clearCompletedTransfers();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
