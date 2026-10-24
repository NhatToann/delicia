import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../themes/colors_frave.dart';

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TextCustom(
                'How do you want to use Delicia?',
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 8),
              const TextCustom(
                'Pick a role to continue.',
                color: ColorsFrave.greyText,
              ),
              const SizedBox(height: 24),
              _RoleCard(
                title: 'Customer',
                description: 'Order food and track delivery',
                icon: Icons.shopping_bag_outlined,
                selected: _selected == '2',
                onTap: () => setState(() => _selected = '2'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: 'Restaurant',
                description: 'Manage menu, orders and deliveries',
                icon: Icons.restaurant_menu,
                selected: _selected == '1',
                onTap: () => setState(() => _selected = '1'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: 'Delivery',
                description: 'Receive and deliver orders',
                icon: Icons.delivery_dining,
                selected: _selected == '3',
                onTap: () => setState(() => _selected = '3'),
              ),
              const Spacer(),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  return BtnFrave(
                    text: 'Continue',
                    onPressed: _selected == null
                        ? null
                        : () {
                            final role = state.rolId;
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
                            // `role` is the persisted role from the auth state
                            // and is intentionally read here so the screen can
                            // later branch (e.g. admin override of a
                            // client/delivery account).
                            assert(role.isNotEmpty);
                          },
                  );
                },
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? ColorsFrave.primaryColor
                : ColorsFrave.greyText.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: ColorsFrave.primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextCustom(
                    title,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 4),
                  TextCustom(
                    description,
                    color: ColorsFrave.greyText,
                    fontSize: 13,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: ColorsFrave.primaryColor),
          ],
        ),
      ),
    );
  }
}
