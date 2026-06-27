import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enginet/core/app_colors.dart';

class QuestionCard extends StatelessWidget {
  final Map question;
  final int? currentUserId;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final VoidCallback onOpenProfile;

  const QuestionCard({
    super.key,
    required this.question,
    required this.currentUserId,
    required this.onTap,
    required this.onLike,
    required this.onSave,
    required this.onDelete,
    required this.onOpenProfile,
  });

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return "";
    final normalized = dateStr.endsWith("Z") ? dateStr : "${dateStr}Z";
    final date = DateTime.tryParse(normalized);
    if (date == null) return "";
    final diff = DateTime.now().toUtc().difference(date.toUtc());
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    final username = question["username"]?.toString() ?? "";
    final profileImage = question["profile_image"]?.toString() ?? "";
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onOpenProfile,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                    backgroundColor: AppColors.cardBg,
                    child: profileImage.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(username, style: GoogleFonts.robotoCondensed(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                  const Spacer(),
                  Text(_timeAgo(question["created_at"]?.toString()), style: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 11)),
                  const SizedBox(width: 8),
                  if (currentUserId != null && question["user_id"] == currentUserId)
                    GestureDetector(onTap: onDelete, child: const Icon(Icons.delete, color: Colors.red, size: 18)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(question["title"]?.toString() ?? "", style: GoogleFonts.robotoCondensed(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 6),
            Text(question["content"]?.toString() ?? "", maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: onLike,
                  child: Icon(
                    (question["is_liked"] == true || question["is_liked"] == 1) ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red, size: 20,
                  ),
                ),
                const SizedBox(width: 4),
                Text("${question["likes"] ?? 0}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                GestureDetector(onTap: onTap, child: const Icon(Icons.chat_bubble, color: Color(0xFF5B7FA6), size: 18)),
                const SizedBox(width: 4),
                Text("${question["answers_count"] ?? 0}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: onSave,
                  child: Icon(
                    (question["is_saved"] == true || question["is_saved"] == 1) ? Icons.bookmark : Icons.bookmark_border,
                    color: AppColors.primary, size: 28,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}