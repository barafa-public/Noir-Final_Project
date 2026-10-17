import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../widgets/empty_view.dart';

/// Placeholder tab Saran & Kesan (form kesan, saran, dan rating menyusul).
class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'Saran & Kesan',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: EmptyView(
              icon: Icons.rate_review_outlined,
              title: 'Segera hadir',
              message:
                  'Form kesan, saran, dan rating mata kuliah akan ada di sini.',
            ),
          ),
        ],
      ),
    );
  }
}
