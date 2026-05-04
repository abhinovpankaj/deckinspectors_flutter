import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'navigation_observer.dart';

class BreadCrumbNavigator extends StatelessWidget {
  final List<Route> currentRouteStack;
  BreadCrumbNavigator({super.key}) : currentRouteStack = routeStack.toList();

  @override
  Widget build(BuildContext context) {
    final crumbs = <Route>[];
    for (final route in currentRouteStack) {
      if (route == currentRouteStack.first || route.settings.name != null) {
        crumbs.add(route);
      }
    }

    return Container(
      height: 26,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDF4), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < crumbs.length; i++) ...
              [
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                GestureDetector(
                  onTap:
                      i == crumbs.length - 1
                          ? null
                          : () {
                            try {
                              Navigator.popUntil(
                                context,
                                (route) => route == crumbs[i],
                              );
                            } catch (e) {
                              debugPrint(e.toString());
                            }
                          },
                  child:
                      i == crumbs.length - 1
                          ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              i == 0
                                  ? 'Home'
                                  : crumbs[i].settings.name as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                          : Text(
                            i == 0
                                ? 'Home'
                                : crumbs[i].settings.name as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
