import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/dark_theme.dart';
import '../../models/weather.dart';
import '../../repositories/repository_provider.dart';

class WeatherLocationDialog extends StatefulWidget {
  final List<WeatherLocation> locations;

  const WeatherLocationDialog({
    super.key,
    required this.locations,
  });

  @override
  State<WeatherLocationDialog> createState() => _WeatherLocationDialogState();
}

class _WeatherLocationDialogState extends State<WeatherLocationDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<WeatherLocation> _searchResults = [];
  List<WeatherLocation> _locations = [];
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locations = List.from(widget.locations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocations() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _searchResults = [];
    });

    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      final results = await repositoryProvider.weatherRepository.searchLocations(query);
      
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _error = 'Failed to search locations: $e';
          _searchResults = [];
        });
      }
    }
  }

  Future<void> _addLocation(WeatherLocation location) async {
    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      await repositoryProvider.weatherRepository.addLocation(location);
      
      // Refresh locations list
      final updatedLocations = await repositoryProvider.weatherRepository.getLocations();
      
      if (mounted) {
        setState(() {
          _locations = updatedLocations;
          _searchResults = [];
          _searchController.clear();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${location.displayName}'),
            backgroundColor: DarkThemeData.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add location: $e'),
            backgroundColor: DarkThemeData.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _removeLocation(String locationId) async {
    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      await repositoryProvider.weatherRepository.removeLocation(locationId);
      
      // Refresh locations list
      final updatedLocations = await repositoryProvider.weatherRepository.getLocations();
      
      if (mounted) {
        setState(() {
          _locations = updatedLocations;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location removed'),
            backgroundColor: DarkThemeData.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove location: $e'),
            backgroundColor: DarkThemeData.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _setDefaultLocation(String locationId) async {
    try {
      final repositoryProvider = Provider.of<RepositoryProvider>(context, listen: false);
      await repositoryProvider.weatherRepository.setDefaultLocation(locationId);
      
      // Refresh locations list
      final updatedLocations = await repositoryProvider.weatherRepository.getLocations();
      
      if (mounted) {
        setState(() {
          _locations = updatedLocations;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default location updated'),
            backgroundColor: DarkThemeData.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update default location: $e'),
            backgroundColor: DarkThemeData.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Manage Weather Locations',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            // Search Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for locations...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: DarkThemeData.accentColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _searchLocations(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSearching ? null : _searchLocations,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DarkThemeData.accentColor,
                          ),
                        )
                      : const Icon(Icons.search, color: DarkThemeData.accentColor),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(40, 40),
                  ),
                ),
              ],
            ),
            
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DarkThemeData.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: DarkThemeData.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: DarkThemeData.errorColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: DarkThemeData.errorColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: DarkThemeData.accentColor,
                      unselectedLabelColor: Colors.white.withOpacity(0.6),
                      indicatorColor: DarkThemeData.accentColor,
                      tabs: [
                        Tab(text: 'Search Results (${_searchResults.length})'),
                        Tab(text: 'My Locations (${_locations.length})'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Search Results Tab
                          _searchResults.isEmpty
                              ? Center(
                                  child: Text(
                                    'Search for locations above',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final location = _searchResults[index];
                                    final alreadyAdded = _locations.any((l) => 
                                        l.latitude == location.latitude && 
                                        l.longitude == location.longitude
                                    );
                                    
                                    return ListTile(
                                      title: Text(
                                        location.name,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        location.displayName,
                                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                      ),
                                      trailing: alreadyAdded
                                          ? Icon(
                                              Icons.check_circle,
                                              color: DarkThemeData.accentColor,
                                            )
                                          : IconButton(
                                              onPressed: () => _addLocation(location),
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                                color: DarkThemeData.accentColor,
                                              ),
                                            ),
                                      dense: true,
                                    );
                                  },
                                ),
                          
                          // My Locations Tab
                          _locations.isEmpty
                              ? Center(
                                  child: Text(
                                    'No locations added yet',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _locations.length,
                                  itemBuilder: (context, index) {
                                    final location = _locations[index];
                                    
                                    return ListTile(
                                      leading: location.isDefault
                                          ? Icon(
                                              Icons.location_on,
                                              color: DarkThemeData.accentColor,
                                            )
                                          : Icon(
                                              Icons.location_on_outlined,
                                              color: Colors.white.withOpacity(0.5),
                                            ),
                                      title: Text(
                                        location.name,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        location.displayName,
                                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        color: Colors.grey[800],
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'default':
                                              _setDefaultLocation(location.id);
                                              break;
                                            case 'remove':
                                              _removeLocation(location.id);
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (!location.isDefault)
                                            const PopupMenuItem<String>(
                                              value: 'default',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.star, color: Colors.white),
                                                  SizedBox(width: 8),
                                                  Text('Set as Default', 
                                                       style: TextStyle(color: Colors.white)),
                                                ],
                                              ),
                                            ),
                                          const PopupMenuItem<String>(
                                            value: 'remove',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Remove', 
                                                     style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      dense: true,
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Done'),
        ),
      ],
    );
  }
}