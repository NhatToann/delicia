import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/btn_frave.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';

/// SelectRoleScreen — choose user role (Customer, Restaurant, Delivery)
/// Material Design 3 style following UI Kit guidelines.
class SelectRoleScreen extends StatefulWidget {
  const SelectRoleScreen({super.key});

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Header
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: ColorsFrave.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: ColorsFrave.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 40,
                  color: ColorsFrave.onPrimary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                context.l10n.introWelcome,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ColorsFrave.darkText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.roleTitle,
                style: const TextStyle(
                  fontSize: 15,
                  color: ColorsFrave.greyText,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),
              // Role Cards
              Expanded(
                child: ListView(
                  children: [
                    _RoleCard(
                      title: context.l10n.roleCustomer,
                      description: context.l10n.roleCustomerSubtitle,
                      icon: Icons.shopping_bag_outlined,
                      selected: _selected == '2',
                      onTap: () => setState(() => _selected = '2'),
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      title: context.l10n.roleRestaurant,
                      description: context.l10n.roleRestaurantSubtitle,
                      icon: Icons.restaurant_outlined,
                      selected: _selected == '1',
                      onTap: () => setState(() => _selected = '1'),
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      title: context.l10n.roleDelivery,
                      description: context.l10n.roleDeliverySubtitle,
                      icon: Icons.delivery_dining,
                      selected: _selected == '3',
                      onTap: () => setState(() => _selected = '3'),
                    ),
                  ],
                ),
              ),
              // Continue Button
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  return BtnFrave(
                    text: context.l10n.actionContinue,
                    onPressed: _selected == null
                        ? null
                        : () {
                            switch (_selected) {
                              case '1':
                                context.go('/admin/home');
                                break;
                              case '2':
                                context.go('/client/home');
                                break;
                              case '3':
                                context.go('/delivery/home');
                                break;
                            }
                            assert(state.rolId.isNotEmpty);
                          },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: selected ? ColorsFrave.primaryContainer : ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        elevation: selected ? 4 : 1,
        shadowColor: selected ? ColorsFrave.primaryColor.withValues(alpha: 0.3) : Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? ColorsFrave.primaryColor : ColorsFrave.surfaceVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected
                        ? ColorsFrave.primaryColor
                        : ColorsFrave.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: selected ? ColorsFrave.onPrimary : ColorsFrave.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: selected ? ColorsFrave.onPrimaryContainer : ColorsFrave.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected ? ColorsFrave.onPrimaryContainer.withValues(alpha: 0.8) : ColorsFrave.greyText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selected Indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? ColorsFrave.primaryColor : ColorsFrave.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: ColorsFrave.onPrimary, size: 18)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
