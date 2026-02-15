import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../data/repositories/ranger_repository.dart';

/// Form screen for creating or editing a ranger.
///
/// When [rangerId] is null, this creates a new ranger via the Edge Function.
/// When [rangerId] is provided, this edits the existing ranger's profile.
class RangerFormScreen extends ConsumerStatefulWidget {
  final String? rangerId;

  const RangerFormScreen({super.key, this.rangerId});

  bool get isEditing => rangerId != null;

  @override
  ConsumerState<RangerFormScreen> createState() => _RangerFormScreenState();
}

class _RangerFormScreenState extends ConsumerState<RangerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields.
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedCheckpostId;
  String? _selectedParkId;

  List<Checkpost> _checkposts = [];
  List<Park> _parks = [];

  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final segmentRepo = ref.read(segmentRepositoryProvider);
      final checkposts = await segmentRepo.listCheckposts();
      final parks = await segmentRepo.listParks();

      if (widget.isEditing) {
        final rangerRepo = ref.read(rangerRepositoryProvider);
        final ranger = await rangerRepo.getRanger(widget.rangerId!);

        _fullNameController.text = ranger.fullName;
        _phoneController.text = ranger.phoneNumber ?? '';
        _selectedCheckpostId = ranger.assignedCheckpostId;
        _selectedParkId = ranger.assignedParkId;
      }

      if (mounted) {
        setState(() {
          _checkposts = checkposts;
          _parks = parks;
          _isInitialLoading = false;
          if (_parks.isNotEmpty && _selectedParkId == null) {
            _selectedParkId = _parks.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load form data: $e';
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rangerRepo = ref.read(rangerRepositoryProvider);

      if (widget.isEditing) {
        await rangerRepo.updateRanger(
          widget.rangerId!,
          UpdateRangerRequest(
            fullName: _fullNameController.text.trim(),
            phoneNumber: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            assignedCheckpostId: _selectedCheckpostId,
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ranger updated successfully.')),
          );
          context.go(RoutePaths.rangers);
        }
      } else {
        await rangerRepo.createRanger(
          CreateRangerRequest(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            assignedCheckpostId: _selectedCheckpostId!,
            assignedParkId: _selectedParkId!,
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ranger created successfully.')),
          );
          context.go(RoutePaths.rangers);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save ranger: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title.
          Row(
            children: [
              IconButton(
                onPressed: () => context.go(RoutePaths.rangers),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isEditing ? 'Edit Ranger' : 'Create Ranger',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Form.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error banner.
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: theme.colorScheme.onErrorContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Username (create only).
                      if (!widget.isEditing) ...[
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            hintText: 'e.g., ram.sharma',
                            helperText:
                                'Will be appended with ${AppConstants.authDomainSuffix}',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Username is required';
                            }
                            if (value.trim().length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            if (value.contains('@') || value.contains(' ')) {
                              return 'Username should not contain @ or spaces';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Password (create only).
                      if (!widget.isEditing) ...[
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Full name.
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Full name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone number.
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '+977-9XXXXXXXXX',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (!widget.isEditing &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Park selection (create only).
                      if (!widget.isEditing) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedParkId,
                          decoration: const InputDecoration(
                            labelText: 'Park',
                            prefixIcon: Icon(Icons.park_outlined),
                          ),
                          items: _parks.map((park) {
                            return DropdownMenuItem(
                              value: park.id,
                              child: Text(park.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedParkId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Park is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Checkpost assignment.
                      DropdownButtonFormField<String>(
                        value: _selectedCheckpostId,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Checkpost',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: _checkposts.map((cp) {
                          return DropdownMenuItem(
                            value: cp.id,
                            child: Text('${cp.name} (${cp.code})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCheckpostId = value;
                          });
                        },
                        validator: (value) {
                          if (!widget.isEditing && value == null) {
                            return 'Checkpost assignment is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Submit button.
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(widget.isEditing
                                  ? 'Update Ranger'
                                  : 'Create Ranger'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
