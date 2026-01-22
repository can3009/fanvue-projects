import 'package:admin_flutter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// --- THEME CONSTANTS (Premium Dark) ---
const kBgColorDark = Color(0xFF0F1115);
const kCardColorDark = Color(0xFF1B222F);
const kPrimaryColor = Color(0xFF06B6D4); // Cyan-500
const kSecondaryColor = Color(0xFF6366F1); // Indigo-500
const kSuccessColor = Color(0xFF10B981);
const kDangerColor = Color(0xFFEF4444);
const kWarningColor = Color(0xFFF59E0B);
const kTextPrimary = Colors.white;
const kTextSecondary = Color(0xFF9CA3AF);

class PPVRequestsDialog extends StatelessWidget {
  const PPVRequestsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    // Mock Data
    final List<Map<String, dynamic>> requests = [
      {
        'user': 'bigfan99',
        'request': 'Custom Birthday Video',
        'price': '\$50',
        'time': '2h ago',
      },
      {
        'user': 'silent_observer',
        'request': 'Feet Pic (Red Nail Polish)',
        'price': '\$20',
        'time': '5h ago',
      },
      {
        'user': 'josh_m',
        'request': 'Exclusive Photoset',
        'price': '\$35',
        'time': '1d ago',
      },
      {
        'user': 'anon_user_12',
        'request': 'Personalized Greeting',
        'price': '\$15',
        'time': '1d ago',
      },
      {
        'user': 'crypto_king',
        'request': '10min Video Call',
        'price': '\$100',
        'time': '2d ago',
      },
    ];

    return Dialog(
      backgroundColor: kCardColorDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kWarningColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: kWarningColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.ppvRequestsTitle,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      strings.manageRequests,
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: kTextSecondary),
                  tooltip: strings.close,
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 48),

            // --- List ---
            Expanded(
              child: ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: kBgColorDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: kPrimaryColor.withOpacity(0.2),
                          child: Text(
                            (req['user'] as String)[0].toUpperCase(),
                            style: const TextStyle(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req['request'],
                                style: const TextStyle(
                                  color: kTextPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${req['user']} • ${req['price']}',
                                style: const TextStyle(
                                  color: kSuccessColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              req['time'],
                              style: TextStyle(
                                color: kTextSecondary.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _ActionButton(
                                  icon: Icons.close,
                                  color: kDangerColor,
                                  onTap: () {},
                                ),
                                const SizedBox(width: 8),
                                _ActionButton(
                                  icon: Icons.check,
                                  color: kSuccessColor,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
