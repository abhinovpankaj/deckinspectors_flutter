import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/users_bloc.dart';
import '../models/couchbase/couchbase_models.dart';
import '../resources/couchbase/project_repository.dart';

import '../bloc/projects_bloc.dart';
import '../bloc/projects_event.dart';
import '../bloc/projects_state.dart';
import 'addedit_project.dart';
import 'app_theme.dart';
import 'cachedimage_widget.dart';
import 'project_details.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  static MaterialPageRoute getRoute() => MaterialPageRoute(
    settings: const RouteSettings(name: 'Home'),
    builder: (context) {
      return BlocProvider(
        create:
            (_) => ProjectsBloc(
              projectRepository: context.read<ProjectRepository>(),
            )..add(LoadProjectsEvent()),
        child: const ProjectsPage(),
      );
    },
  );

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  late String userFullName;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    var loggedInUser = usersBloc.userDetails;
    userFullName = loggedInUser.firstname as String;
    userFullName = "$userFullName ${loggedInUser.lastname as String}";
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Project getProject() {
    return Project(
      name: "",
      isInvasive: false,
      description: "",
      address: "",
      url: "",
      projecttype: 'multilevel',
      children: [],
      latitude: 28.7,
      longitude: 77.1,
      createdby: userFullName,
    );
  }

  void addEditProject() {
    Navigator.push(
      context,
      AddEditProjectPage.getRoute(getProject(), true, userFullName),
    ).then((value) {
      if (value == true) {
        try {
          context.read<ProjectsBloc>().add(LoadProjectsEvent());
        } catch (_) {}
        setState(() {});
      }
    });
  }

  void gotoProjectDetails(String projectId, String projName) {
    Navigator.push(
      context,
      ProjectDetailsPage.getRoute(projectId, userFullName, false, projName),
    ).then((value) {
      try {
        context.read<ProjectsBloc>().add(LoadProjectsEvent());
      } catch (_) {}
      setState(() => {});
    });
  }

  void gotoInvasiveProjectDetails(String projectId, String projName) {
    Navigator.push(
      context,
      ProjectDetailsPage.getRoute(projectId, userFullName, true, projName),
    ).then((value) {
      try {
        context.read<ProjectsBloc>().add(LoadProjectsEvent());
      } catch (_) {}
      setState(() => {});
    });
  }

  String _formatEditedAt(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Projects', style: AppTextStyles.headlineMedium),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged:
                  (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search projects…',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                        : null,
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<ProjectsBloc, ProjectsState>(
              builder: (context, state) {
                if (state is ProjectsLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is ProjectsLoaded) {
                  final allProjects = state.projects;
                  final projects =
                      _searchQuery.isEmpty
                          ? allProjects
                          : allProjects
                              .where(
                                (p) =>
                                    (p.name ?? '').toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    (p.address ?? '').toLowerCase().contains(
                                      _searchQuery,
                                    ),
                              )
                              .toList();

                  if (projects.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 64,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No projects match your search'
                                : 'No projects yet',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Tap "New" to add your first project',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      return _ProjectCard(
                        project: projects[index],
                        onVisualTap: () {
                          if (projects[index].projecttype == 'singlelevel') {
                            gotoSingleLevelProject(
                              projects[index].id ?? '',
                              projects[index].name ?? '',
                            );
                          } else {
                            gotoProjectDetails(
                              projects[index].id ?? '',
                              projects[index].name ?? '',
                            );
                          }
                        },
                        onInvasiveTap: () {
                          if (projects[index].projecttype == 'singlelevel') {
                            gotoInvasiveSingleProject(projects[index].id ?? '');
                          } else {
                            gotoInvasiveProjectDetails(
                              projects[index].id ?? '',
                              projects[index].name ?? '',
                            );
                          }
                        },
                        formattedDate: _formatEditedAt(
                          projects[index].editedat,
                        ),
                      );
                    },
                  );
                } else if (state is ProjectsError) {
                  return Center(child: Text('Error: ${state.message}'));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEditProject,
        icon: const Icon(Icons.add),
        label: const Text('Add Project'),
      ),
    );
  }

  void gotoSingleLevelProject(String id, String projName) {
    // Navigator.push(
    //         context,
    //         SingleProjectDetailsPage.getRoute(
    //             id, userFullName, false, projName))
    //     .then((value) => setState(() => {}));
  }

  void gotoInvasiveSingleProject(String id) {
    // Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) =>
    //             SingleProjectDetailsPage(id, userFullName, true)));
  }
}

// ─── Project Card ──────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onVisualTap;
  final VoidCallback onInvasiveTap;
  final String formattedDate;

  const _ProjectCard({
    required this.project,
    required this.onVisualTap,
    required this.onInvasiveTap,
    required this.formattedDate,
  });

  Color get _accentColor =>
      project.projecttype == 'singlelevel'
          ? AppColors.singleLevel
          : AppColors.multiLevel;

  String get _typeLabel =>
      project.projecttype == 'singlelevel' ? 'Single-Level' : 'Multi-Level';

  String get _initials {
    final name = project.name ?? '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onVisualTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left accent + thumbnail
              GestureDetector(
                onTap: onVisualTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child:
                        project.url != null && project.url!.isNotEmpty
                            ? cachedNetworkImage(project.url)
                            : Container(
                              color: _accentColor.withAlpha(30),
                              alignment: Alignment.center,
                              child: Text(
                                _initials,
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row + type chip
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _typeLabel,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: _accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Address
                    if ((project.address ?? '').isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              project.address ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    if (formattedDate.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Updated $formattedDate',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Action buttons — full width, spread left/right
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Visual',
                            icon: Icons.visibility_outlined,
                            color: AppColors.primary,
                            onTap: onVisualTap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            label: 'Invasive',
                            icon: Icons.construction_outlined,
                            color: AppColors.accent,
                            onTap: onInvasiveTap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
