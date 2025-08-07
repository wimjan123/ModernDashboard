import 'package:flutter/material.dart';
import '../core/theme/dark_theme.dart';
import '../widgets/common/glass_card.dart';
import '../firebase/migration_service.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  bool _isLoading = true;
  bool _isMigrating = false;
  String? _error;
  MigrationSummary? _summary;
  MigrationResult? _result;
  String _currentProgress = '';

  // Migration options
  bool _migrateSettings = true;
  bool _migrateTodos = true;
  bool _migrateUserPreferences = true;
  bool _cleanupLegacyData = true;

  @override
  void initState() {
    super.initState();
    _loadMigrationSummary();
  }

  Future<void> _loadMigrationSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await MigrationService.instance.getMigrationSummary();
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to analyze migration data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _performMigration() async {
    setState(() {
      _isMigrating = true;
      _error = null;
      _result = null;
      _currentProgress = 'Initializing...';
    });

    try {
      final result = await MigrationService.instance.performMigration(
        migrateSettings: _migrateSettings,
        migrateTodos: _migrateTodos,
        migrateUserPreferences: _migrateUserPreferences,
        onProgress: (progress) {
          setState(() {
            _currentProgress = progress;
          });
        },
      );

      setState(() {
        _result = result;
        _isMigrating = false;
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Migration completed successfully!'),
            backgroundColor: DarkThemeData.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Migration failed: $e';
        _isMigrating = false;
      });
    }
  }

  Widget _buildMigrationSummary() {
    if (_summary == null) return const SizedBox();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: DarkThemeData.accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Migration Analysis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_summary!.settingsToMigrate.isNotEmpty) ...[
            _buildDataRow(
              'Settings',
              '${_summary!.settingsToMigrate.length} items',
              Icons.settings_rounded,
              DarkThemeData.accentColor,
            ),
            const SizedBox(height: 8),
          ],
          
          if (_summary!.totalItems > 0) ...[
            _buildDataRow(
              'User Preferences',
              '${_summary!.legacyKeys.length} preferences',
              Icons.person_rounded,
              DarkThemeData.warningColor,
            ),
            const SizedBox(height: 8),
          ],
          
          _buildDataRow(
            'Legacy Data',
            '${_summary!.totalItems} total items',
            Icons.storage_rounded,
            DarkThemeData.errorColor,
          ),
          
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DarkThemeData.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'This will migrate your local data to Firebase for cross-device synchronization. Your original data will be backed up before migration.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DarkThemeData.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String count, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          count,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMigrationOptions() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: DarkThemeData.successColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Migration Options',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          CheckboxListTile(
            title: const Text('Settings & Preferences'),
            subtitle: const Text('Dashboard settings, widget preferences'),
            value: _migrateSettings,
            onChanged: _isMigrating ? null : (value) {
              setState(() {
                _migrateSettings = value ?? true;
              });
            },
            activeColor: DarkThemeData.accentColor,
          ),
          
          CheckboxListTile(
            title: const Text('Todo Tasks'),
            subtitle: const Text('Local todo items and categories'),
            value: _migrateTodos,
            onChanged: _isMigrating ? null : (value) {
              setState(() {
                _migrateTodos = value ?? true;
              });
            },
            activeColor: DarkThemeData.successColor,
          ),
          
          CheckboxListTile(
            title: const Text('User Preferences'),
            subtitle: const Text('Weather locations, news feeds, app state'),
            value: _migrateUserPreferences,
            onChanged: _isMigrating ? null : (value) {
              setState(() {
                _migrateUserPreferences = value ?? true;
              });
            },
            activeColor: DarkThemeData.warningColor,
          ),
          
          const Divider(),
          
          CheckboxListTile(
            title: const Text('Clean Up Legacy Data'),
            subtitle: const Text('Remove local data after successful migration'),
            value: _cleanupLegacyData,
            onChanged: _isMigrating ? null : (value) {
              setState(() {
                _cleanupLegacyData = value ?? true;
              });
            },
            activeColor: DarkThemeData.errorColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationResult() {
    if (_result == null) return const SizedBox();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _result!.success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: _result!.success ? DarkThemeData.successColor : DarkThemeData.errorColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _result!.success ? 'Migration Successful' : 'Migration Failed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _result!.success ? DarkThemeData.successColor : DarkThemeData.errorColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_result!.success) ...[
            _buildResultRow('Settings Migrated', '${_result!.settingsMigrated}', Icons.settings_rounded),
            _buildResultRow('Preferences Migrated', '${_result!.preferencesMigrated}', Icons.person_rounded),
            _buildResultRow('Todos Migrated', '${_result!.todosMigrated}', Icons.checklist_rounded),
            _buildResultRow('Legacy Data Cleaned', '${_result!.legacyDataCleaned}', Icons.cleaning_services_rounded),
            
            if (_result!.completedAt != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DarkThemeData.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Completed at: ${_result!.completedAt.toString().substring(0, 19)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DarkThemeData.successColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ] else ...[
            Text(
              _result!.error ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DarkThemeData.errorColor,
              ),
            ),
            if (_result!.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DarkThemeData.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Errors:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DarkThemeData.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...(_result!.errors.map((error) => Text(
                      '• $error',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DarkThemeData.errorColor,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    )).toList()),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: DarkThemeData.successColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DarkThemeData.successColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Data Migration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isMigrating ? null : () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              DarkThemeData.accentColor.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.background,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analyzing migration data...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Header
                      Text(
                        'Migrate to Firebase',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Transfer your local data to Firebase for cloud synchronization',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Error display
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: DarkThemeData.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DarkThemeData.errorColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: DarkThemeData.errorColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: DarkThemeData.errorColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Migration Summary
                      _buildMigrationSummary(),
                      const SizedBox(height: 20),
                      
                      // Migration Options
                      _buildMigrationOptions(),
                      const SizedBox(height: 20),
                      
                      // Migration Progress/Result
                      if (_isMigrating)
                        GlassCard(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Migrating Data...',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentProgress,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: DarkThemeData.accentColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_result != null)
                        _buildMigrationResult()
                      else
                        // Start Migration Button
                        Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_migrateSettings || _migrateTodos || _migrateUserPreferences) 
                                ? _performMigration 
                                : null,
                            icon: const Icon(Icons.cloud_sync_rounded),
                            label: const Text('Start Migration'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DarkThemeData.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}