import 'package:cached_network_image/cached_network_image.dart';
import 'package:enginet/core/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class EngineerProfileScreen extends StatefulWidget {
  final int? targetUserId;

  const EngineerProfileScreen({super.key, this.targetUserId});

  @override
  State<EngineerProfileScreen> createState() => _EngineerProfileScreenState();
}

class _EngineerProfileScreenState extends State<EngineerProfileScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? user;
  List<dynamic> posts = [];
  List<dynamic> books = [];
  List<dynamic> articles = [];
  bool isLoading = true;
  bool isOwnProfile = false;
  bool isFollowing = false;
  bool followLoading = false;
  int? currentUserId;
  int selectedTab = 0;
  int followersCount = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }
  
  Future<String?> _pickAndUploadProfileImage() async {
  final pickedFile = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
  );

  if (pickedFile == null) return null;

  final file = File(pickedFile.path);
  final username = await SessionManager.getUsername() ?? 'user';
  final fileExt = path.extension(file.path);
  final fileName =
      '${DateTime.now().millisecondsSinceEpoch}_$username$fileExt';

  final filePath = 'profile-images/$fileName';

  await _supabase.storage.from('profiles').upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

  return _supabase.storage.from('profiles').getPublicUrl(filePath);
}



  Future<void> loadProfile() async {
  try {
    final email = await SessionManager.getEmail();

    if (email == null || email.isEmpty) {
      if (!mounted) return;
      setState(() => isLoading = false);
      return;
    }

    final currentUserRes = await _supabase
        .from('users')
        .select()
        .eq('email', email)
        .single();

    currentUserId = currentUserRes['id'] as int;

    final targetId = widget.targetUserId ?? currentUserId!;
    isOwnProfile = (targetId == currentUserId);

    final userRes = await _supabase
        .from('users')
        .select()
        .eq('id', targetId)
        .single();

    final targetUsername = userRes['username'];

    final results = await Future.wait([
      _supabase
          .from('posts')
          .select()
          .eq('username', targetUsername)
          .order('created_at', ascending: false),

      _supabase
          .from('books')
          .select()
          .eq('author_username', targetUsername)
          .order('created_at', ascending: false),

      _supabase
          .from('articles')
          .select()
          .eq('author_name', targetUsername)
          .order('created_at', ascending: false),

      _supabase
          .from('follows')
          .select('id')
          .eq('following_id', targetId),

      if (!isOwnProfile)
        _supabase
            .from('follows')
            .select()
            .eq('follower_id', currentUserId!)
            .eq('following_id', targetId),
    ]);

    if (!mounted) return;

    setState(() {
      user = userRes;
      posts = results[0] as List;
      books = results[1] as List;
      articles = results[2] as List;
      followersCount = (results[3] as List).length;

      if (!isOwnProfile && results.length > 4) {
        isFollowing = (results[4] as List).isNotEmpty;
      }

      isLoading = false;
    });
  } catch (e) {
    debugPrint('❌ Error loading profile: $e');
    if (!mounted) return;
    setState(() => isLoading = false);
  }
}

  Future<void> toggleFollow() async {
    if (currentUserId == null || user == null) return;
    final targetId = user!['id'] as int;

    setState(() => followLoading = true);
    try {
      if (isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId!)
            .eq('following_id', targetId);

        if (!mounted) return;
        setState(() {
          isFollowing = false;
          if (followersCount > 0) followersCount--;
        });
      } else {
        await _supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': targetId,
        });

        await _supabase.from('notifications').insert({
          'user_id': targetId,
          'message': 'You have a new follower.',
          'is_read': 0,
        });

        if (!mounted) return;
        setState(() {
          isFollowing = true;
          followersCount++;
        });
      }
    } catch (e) {
      debugPrint('❌ Follow error: $e');
    } finally {
      if (mounted) setState(() => followLoading = false);
    }
  }

  void showEditDialog() {
  final bioController = TextEditingController(text: user?['bio'] ?? '');
  String? tempSelectedImageUrl;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF071739),
      title: Text(
        'Edit Profile',
        style: GoogleFonts.agbalumo(color: const Color(0xFFE3C39D)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dialogField(bioController, 'Bio', maxLines: 3),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final imageUrl = await _pickAndUploadProfileImage();
              if (imageUrl == null) return;

              tempSelectedImageUrl = imageUrl;

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image selected. Press Save to update.'),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE3C39D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.image, color: Colors.black54),
                  SizedBox(width: 10),
                  Text(
                    'Choose profile image',
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () async {
            final email = await SessionManager.getEmail();
            if (email == null) return;

            final updateData = {
              'bio': bioController.text,
            };

            if (tempSelectedImageUrl != null) {
              updateData['profile_image'] = tempSelectedImageUrl!;
            }

            await _supabase.from('users').update(updateData).eq('email', email);

            if (!mounted) return;
            Navigator.pop(dialogContext);
            loadProfile();
          },
          child: Text(
            'Save',
            style: GoogleFonts.agbalumo(color: const Color(0xFFE3C39D)),
          ),
        ),
      ],
    ),
  );
}

  Widget _dialogField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE3C39D),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(border: InputBorder.none, hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF071739),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C94C6)),
        ),
      );
    }

    final username = user?['username'] ?? '';
    final bio = user?['bio'] ?? '';
    final profileImage = user?['profile_image'] ?? '';
    final points = user?['points'] ?? 0;
    final university = user?['university'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF071739),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
  if (Navigator.canPop(context)) {
    Navigator.pop(context);
  } else {
    Navigator.pushReplacementNamed(context, '/home');
  }
},
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3C39D),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    username,
                    style: GoogleFonts.agbalumo(
                      color: const Color(0xFFE3C39D),
                      fontSize: 22,
                    ),
                  ),
                  const Spacer(),
                  if (isOwnProfile)
                    GestureDetector(
                      onTap: showEditDialog,
                      child: const Icon(Icons.edit, color: Color(0xFFE3C39D)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 90,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8C09A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE3C39D),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: profileImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profileImage,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white54,
                              ),
                              placeholder: (c, u) => Shimmer.fromColors(
                                baseColor: const Color(0xFF1A2F55),
                                highlightColor: const Color(0xFF2A4A7F),
                                child: Container(color: Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white54,
                            ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        _statRow('Posts', '${posts.length}'),
                        const SizedBox(height: 10),
                        _statRow('Followers', '$followersCount'),
                        const SizedBox(height: 10),
                        _statRow('Points', '$points'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$username${university.isNotEmpty ? '\n$university' : ''}${bio.isNotEmpty ? '\n$bio' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (!isOwnProfile)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: followLoading ? null : toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? const Color(0xFF1A2F55)
                          : const Color(0xFFE3C39D),
                      foregroundColor:
                          isFollowing ? const Color(0xFFE3C39D) : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xFFE3C39D),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: followLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE3C39D),
                            ),
                          )
                        : Text(
                            isFollowing ? 'Following ✓' : 'Follow',
                            style: GoogleFonts.agbalumo(fontSize: 16),
                          ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            Row(
              children: [
                _tab('Posts', 0),
                _tab('Books', 1),
                _tab('Articles', 2),
              ],
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: selectedTab == 0
                  ? _buildPostsList()
                  : selectedTab == 1
                      ? _buildBooksList()
                      : _buildArticlesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      );

  Widget _tab(String label, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFFE3C39D)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.agbalumo(
                color: isSelected
                    ? const Color(0xFFE3C39D)
                    : Colors.white54,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    if (posts.isEmpty) {
      return const Center(
        child: Text('No posts yet', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final profileImage = user?['profile_image'] ?? '';
        final username = user?['username'] ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD8C09A),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage:
                        profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                    backgroundColor: const Color(0xFF4A6FA5),
                  ),
                  const SizedBox(width: 8),
                  Text(username, style: GoogleFonts.agbalumo(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post['content'] ?? '',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.favorite_border, size: 18),
                  const SizedBox(width: 4),
                  Text('${post['likes'] ?? 0}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBooksList() {
    if (books.isEmpty) {
      return const Center(
        child: Text('No books', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD8C09A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: book['image_url'] != null && book['image_url'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: book['image_url'],
                      width: 50,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => const Icon(Icons.book, size: 40),
                      placeholder: (c, u) => Shimmer.fromColors(
                        baseColor: const Color(0xFF1A2F55),
                        highlightColor: const Color(0xFF2A4A7F),
                        child: Container(
                          width: 50,
                          height: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : const Icon(Icons.book, size: 40),
            title: Text(
              book['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              book['author'] ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArticlesList() {
    if (articles.isEmpty) {
      return const Center(
        child: Text('No articles', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD8C09A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: article['image_url'] != null &&
                    article['image_url'].isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: article['image_url'],
                      width: 50,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) =>
                          const Icon(Icons.article, size: 40),
                      placeholder: (c, u) => Shimmer.fromColors(
                        baseColor: const Color(0xFF1A2F55),
                        highlightColor: const Color(0xFF2A4A7F),
                        child: Container(
                          width: 50,
                          height: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : const Icon(Icons.article, size: 40),
            title: Text(
              article['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              article['author_name'] ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}