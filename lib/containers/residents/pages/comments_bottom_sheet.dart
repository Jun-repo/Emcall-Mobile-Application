import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsBottomSheet extends StatefulWidget {
  final int reelId;
  final List<dynamic> initialComments;
  final SupabaseClient supabase;
  final String workerUsername;

  const CommentsBottomSheet({
    super.key,
    required this.reelId,
    required this.initialComments,
    required this.supabase,
    required this.workerUsername,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> parentComments = [];
  bool isSending = false;
  bool isLoadingComments = true;
  bool isLoadingCounts = true;
  final ScrollController _scrollController = ScrollController();
  int? _replyingToCommentId;
  final FocusNode _commentFocusNode = FocusNode();
  final Map<int, bool> _childCommentsVisible = {};
  RealtimeChannel? _subscription;
  Map<String, int> reactionCounts = {
    'like': 0,
    'love': 0,
    'hahaha': 0,
    'angry': 0,
  };
  int viewCount = 0;
  int commentCount = 0;
  int badReactionCount = 0;
  bool _showSendIcon = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _sortAndStructureComments(widget.initialComments);
    _fetchComments().then((_) {
      _fetchCounts();
    });
    _setupRealtimeSubscription();
    _commentController.addListener(() {
      final showSend = _commentController.text.trim().isNotEmpty;
      if (showSend != _showSendIcon) {
        setState(() {
          _showSendIcon = showSend;
        });
        if (showSend) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      }
    });
  }

  Future<void> _fetchComments() async {
    setState(() {
      isLoadingComments = true;
    });
    try {
      final response = await widget.supabase
          .from('reels_comments')
          .select(
              'id, comment_text, created_at, parent_comment_id, residents ( first_name, middle_name, last_name, suffix_name, profile_image )')
          .eq('reel_id', widget.reelId);
      if (mounted) {
        _sortAndStructureComments(List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comments: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _fetchCounts() async {
    try {
      final commentResponse = await widget.supabase
          .from('reels_comments')
          .select('id')
          .eq('reel_id', widget.reelId);
      final commentCnt = (commentResponse as List).length;

      final reactionResponse = await widget.supabase
          .from('reels_reactions')
          .select('reaction_type')
          .eq('reel_id', widget.reelId);
      final reactions = List<Map<String, dynamic>>.from(reactionResponse);
      final reactionCnts = {
        'like': 0,
        'love': 0,
        'hahaha': 0,
        'angry': 0,
      };
      for (var reaction in reactions) {
        final type = reaction['reaction_type'] as String;
        reactionCnts[type] = (reactionCnts[type] ?? 0) + 1;
      }

      final badReactionResponse = await widget.supabase
          .from('reels_bad_reactions')
          .select('id')
          .eq('reel_id', widget.reelId);
      final badReactionCnt = (badReactionResponse as List).length;

      if (mounted) {
        setState(() {
          commentCount = commentCnt;
          reactionCounts = reactionCnts;
          badReactionCount = badReactionCnt;
          isLoadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading counts: $e')),
        );
      }
      setState(() {
        isLoadingCounts = false;
      });
    }
  }

  void _setupRealtimeSubscription() {
    _subscription = widget.supabase
        .channel('reels_comments')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reels_comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'reel_id',
            value: widget.reelId,
          ),
          callback: (payload) {
            final newComment = payload.newRecord;
            if (mounted) {
              setState(() {
                bool commentExists = parentComments
                        .any((parent) => parent['id'] == newComment['id']) ||
                    parentComments.any((parent) => parent['children']
                        .any((child) => child['id'] == newComment['id']));

                if (!commentExists) {
                  widget.supabase
                      .from('residents')
                      .select(
                          'first_name, middle_name, last_name, suffix_name, profile_image')
                      .eq('id', newComment['resident_id'])
                      .single()
                      .then((resident) {
                    if (mounted) {
                      setState(() {
                        final commentWithResident = {
                          ...newComment,
                          'residents': resident,
                        };
                        if (newComment['parent_comment_id'] == null) {
                          parentComments.insert(0, {
                            ...commentWithResident,
                            'children': [],
                          });
                          _childCommentsVisible[newComment['id']] = false;
                        } else {
                          for (var parent in parentComments) {
                            if (parent['id'] ==
                                newComment['parent_comment_id']) {
                              parent['children'].insert(0, commentWithResident);
                              _childCommentsVisible[parent['id']] = true;
                              break;
                            }
                          }
                        }
                        commentCount += 1;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        });
                      });
                    }
                  });
                }
              });
            }
          },
        )
        .subscribe();

    widget.supabase
        .channel('reels_reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reels_reactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'reel_id',
            value: widget.reelId,
          ),
          callback: (payload) {
            final newReaction = payload.newRecord;
            if (mounted) {
              setState(() {
                final reactionType = newReaction['reaction_type'] as String;
                reactionCounts[reactionType] =
                    (reactionCounts[reactionType] ?? 0) + 1;
              });
            }
          },
        )
        .subscribe();

    widget.supabase
        .channel('reels_bad_reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reels_bad_reactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'reel_id',
            value: widget.reelId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                badReactionCount += 1;
              });
            }
          },
        )
        .subscribe();
  }

  void _sortAndStructureComments(List<dynamic> commentsList) {
    List<Map<String, dynamic>> allComments =
        List<Map<String, dynamic>>.from(commentsList);

    List<Map<String, dynamic>> parents = allComments
        .where((comment) => comment['parent_comment_id'] == null)
        .toList();

    parents.sort((a, b) => DateTime.parse(b['created_at'])
        .compareTo(DateTime.parse(a['created_at'])));

    List<Map<String, dynamic>> structuredComments = [];
    for (var parent in parents) {
      List<Map<String, dynamic>> children = allComments
          .where((comment) =>
              comment['parent_comment_id'] == parent['id'] &&
              comment['id'] != parent['id'])
          .toList();

      children.sort((a, b) => DateTime.parse(b['created_at'])
          .compareTo(DateTime.parse(a['created_at'])));

      structuredComments.add({
        ...parent,
        'children': children,
      });

      _childCommentsVisible[parent['id']] = false;
    }

    setState(() {
      parentComments = structuredComments;
      isLoadingComments = false;
    });
  }

  Future<int?> getCurrentResidentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('resident_id');
  }

  Future<void> _sendComment({int? parentCommentId}) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      isSending = true;
    });

    try {
      final int? residentId = await getCurrentResidentId();
      if (residentId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to comment')),
          );
        }
        setState(() {
          isSending = false;
        });
        return;
      }

      final commentData = {
        'reel_id': widget.reelId,
        'resident_id': residentId,
        'comment_text': text,
        if (parentCommentId != null) 'parent_comment_id': parentCommentId,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await widget.supabase
          .from('reels_comments')
          .insert(commentData)
          .select(
              'id, comment_text, created_at, parent_comment_id, residents ( first_name, middle_name, last_name, suffix_name, profile_image )')
          .single();

      if (mounted) {
        setState(() {
          final newComment = Map<String, dynamic>.from(response);
          if (parentCommentId == null) {
            parentComments.insert(0, {
              ...newComment,
              'children': [],
            });
            _childCommentsVisible[newComment['id']] = false;
          } else {
            for (var parent in parentComments) {
              if (parent['id'] == parentCommentId) {
                parent['children'].insert(0, newComment);
                _childCommentsVisible[parent['id']] = true;
                break;
              }
            }
          }
          commentCount += 1;
          _commentController.clear();
          _replyingToCommentId = null;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  String _formatTimeDifference(String createdAt) {
    final DateTime commentTime = DateTime.parse(createdAt).toLocal();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(commentTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} sec${difference.inSeconds == 1 ? '' : 's ago'}';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's ago'}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr${difference.inHours == 1 ? '' : 's ago'}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's ago'}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's ago'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months mo${months == 1 ? '' : 's ago'}';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years yr${years == 1 ? '' : 's ago'}';
    }
  }

  void _onReply(int commentId) {
    setState(() {
      _replyingToCommentId = commentId;
    });
    _commentFocusNode.requestFocus();
  }

  int _getReplyDepth(
      int? parentCommentId, List<Map<String, dynamic>> allComments) {
    if (parentCommentId == null) return 0;
    final parentComment = allComments.firstWhere(
      (c) => c['id'] == parentCommentId,
      orElse: () => <String, dynamic>{},
    );
    if (parentComment.isEmpty) return 1;
    return 1 + _getReplyDepth(parentComment['parent_comment_id'], allComments);
  }

  void _toggleChildComments(int parentId) {
    setState(() {
      _childCommentsVisible[parentId] =
          !(_childCommentsVisible[parentId] ?? false);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.removeListener(() {
      _showSendIcon = _commentController.text.trim().isNotEmpty;
    });
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Widget _buildCommentCard(Map<String, dynamic> comment, int depth) {
    final resident = comment['residents'] as Map<String, dynamic>?;

    final residentName = resident != null
        ? [
            resident['first_name'],
            resident['middle_name']?.isNotEmpty == true
                ? '${resident['middle_name'][0]}.'
                : '',
            resident['last_name'],
            resident['suffix_name']?.isNotEmpty == true
                ? resident['suffix_name']
                : '',
          ].where((part) => part.isNotEmpty).join(' ')
        : 'Anonymous';

    String displayText = comment['comment_text'] ?? '';
    displayText = '$displayText';

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0 + (depth * 40.0),
        right: 16.0,
        top: 8.0,
        bottom: 8.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: const Color.fromARGB(128, 183, 181, 181),
                radius: depth == 0 ? 20 : 16 - (depth * 2),
                child: CircleAvatar(
                  radius: depth == 0 ? 18 : 14 - (depth * 2),
                  backgroundImage: resident?['profile_image'] != null
                      ? NetworkImage(resident!['profile_image'])
                      : null,
                  child: resident?['profile_image'] == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
              ),
              Positioned(
                top: depth == 0 ? 3 : 1,
                right: depth == 0 ? -8 : -5,
                child: Container(
                  width: depth == 0 ? 10 : 8,
                  height: depth == 0 ? 10 : 8,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 240, 242, 245),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Card(
                      color: const Color.fromARGB(255, 240, 242, 245),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(36),
                          bottomLeft: Radius.circular(36),
                          topRight: Radius.circular(36),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      elevation: 5,
                      shadowColor: Colors.black.withOpacity(0.35),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              residentName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayText,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      left: 2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 240, 242, 245),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      comment['created_at'] != null
                          ? _formatTimeDifference(comment['created_at'])
                          : '',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _onReply(comment['id']),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountsRow() {
    final reactionIcons = {
      'like': Icons.thumb_up,
      'love': Icons.favorite,
      'helpful': Icons.lightbulb,
      'hahaha': Icons.emoji_emotions,
      'care': Icons.volunteer_activism,
      'angry': Icons.mood_bad,
    };

    List<Widget> reactionWidgets = reactionCounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  Icon(
                    reactionIcons[entry.key],
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Row(
            children: [
              const Icon(
                Icons.comment,
                size: 16,
                color: Colors.blue,
              ),
              const SizedBox(width: 2),
              Text(
                '$commentCount',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(width: 16),
          ...reactionWidgets,
          if (badReactionCount > 0) ...[
            const SizedBox(width: 16),
            Row(
              children: [
                const Icon(
                  Icons.thumb_down,
                  size: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 2),
                Text(
                  '$badReactionCount',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _getReplyUsername() {
    if (_replyingToCommentId == null) {
      return widget.workerUsername;
    }
    for (var parent in parentComments) {
      if (parent['id'] == _replyingToCommentId) {
        final resident = parent['residents'] as Map<String, dynamic>?;
        return resident != null
            ? [
                resident['first_name'],
                resident['middle_name']?.isNotEmpty == true
                    ? '${resident['middle_name'][0]}.'
                    : '',
                resident['last_name'],
                resident['suffix_name']?.isNotEmpty == true
                    ? resident['suffix_name']
                    : '',
              ].where((part) => part.isNotEmpty).join(' ')
            : 'Anonymous';
      }
      for (var child in (parent['children'] as List)) {
        if (child['id'] == _replyingToCommentId) {
          final resident = child['residents'] as Map<String, dynamic>?;
          return resident != null
              ? [
                  resident['first_name'],
                  resident['middle_name']?.isNotEmpty == true
                      ? '${resident['middle_name'][0]}.'
                      : '',
                  resident['last_name'],
                  resident['suffix_name']?.isNotEmpty == true
                      ? resident['suffix_name']
                      : '',
                ].where((part) => part.isNotEmpty).join(' ')
              : 'Anonymous';
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final replyUsername = _getReplyUsername();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, __) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Gilroy',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (!isLoadingComments && !isLoadingCounts) _buildCountsRow(),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          parentComments.length + (isLoadingComments ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isLoadingComments &&
                            index == parentComments.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.redAccent,
                                strokeWidth: 3,
                              ),
                            ),
                          );
                        }
                        final parent = parentComments[index];
                        final List<Map<String, dynamic>> children =
                            List<Map<String, dynamic>>.from(
                                parent['children'] ?? []);
                        final bool isExpanded =
                            _childCommentsVisible[parent['id']] ?? false;

                        List<Widget> commentWidgets = [
                          _buildCommentCard(parent, 0),
                        ];

                        if (children.isNotEmpty) {
                          commentWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 68.0,
                                  right: 16.0,
                                  top: 4.0,
                                  bottom: 4.0),
                              child: TextButton(
                                onPressed: () =>
                                    _toggleChildComments(parent['id']),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  isExpanded
                                      ? 'Hide replies'
                                      : 'View all (${children.length})',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        if (isExpanded) {
                          for (var child in children) {
                            final depth = _getReplyDepth(
                                child['parent_comment_id'], parentComments);
                            commentWidgets.add(_buildCommentCard(child, depth));
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: commentWidgets,
                        );
                      },
                    ),
                    if (isLoadingComments && parentComments.isEmpty)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.redAccent,
                          strokeWidth: 3,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replyUsername != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Sending a message to ',
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 10,
                                  color: Color.fromARGB(255, 54, 54, 54),
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2.0,
                                      color: Colors.black54,
                                      offset: Offset(2.0, 2.0),
                                    ),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: replyUsername,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: Color.fromARGB(255, 29, 29, 29),
                                  shadows: [
                                    Shadow(
                                      blurRadius: 3.0,
                                      color: Colors.black54,
                                      offset: Offset(2.0, 2.0),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              style: const TextStyle(color: Colors.black),
                              maxLines: null,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(
                                hintText: _replyingToCommentId != null
                                    ? 'Replying to comment...'
                                    : 'Type a comment...',
                                hintStyle: const TextStyle(
                                  color: Colors.black54,
                                  fontFamily: 'Gilroy',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                fillColor: Colors.grey[200],
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        isSending
                            ? const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  color: Colors.redAccent,
                                  strokeWidth: 2,
                                ),
                              )
                            : ScaleTransition(
                                scale: _scaleAnimation,
                                child: FadeTransition(
                                  opacity: _opacityAnimation,
                                  child: _showSendIcon
                                      ? Container(
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.redAccent,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.send,
                                                color: Colors.white),
                                            onPressed: () => _sendComment(
                                                parentCommentId:
                                                    _replyingToCommentId),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
