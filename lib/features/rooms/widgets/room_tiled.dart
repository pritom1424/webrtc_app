import 'package:flutter/material.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/rooms/model/room_model.dart';

// isJoined = true  → "Joined" chip shown, entire tile tappable
// isJoined = false → "Join" button shown, tile NOT tappable
class RoomTile extends StatefulWidget {
  final RoomModel room;
  final bool isJoined;
  final Future<void> Function() onJoin;
  final VoidCallback? onTap;
  const RoomTile({
    super.key,
    required this.room,
    required this.isJoined,
    required this.onJoin,
    this.onTap,
  });

  @override
  State<RoomTile> createState() => _RoomTileState();
}

class _RoomTileState extends State<RoomTile> {
  bool _isJoining = false;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: widget.onTap, // null if not joined — makes tile non-tappable
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),

      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(
            alpha: widget.isJoined ? 0.15 : 0.06,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.meeting_room_rounded,
          color: widget.isJoined ? AppTheme.primaryBlue : Colors.grey,
        ),
      ),

      title: Text(
        widget.room.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: widget.isJoined ? AppTheme.textDark : Colors.grey[600],
        ),
      ),

      subtitle: Text(
        '${widget.room.members.length} member${widget.room.members.length != 1 ? 's' : ''}',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),

      trailing: widget.isJoined
          // ── Joined state ──
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'Joined',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            )
          // ── Not joined state ──
          : SizedBox(
              width: 72,
              height: 34,
              child: ElevatedButton(
                onPressed: _isJoining
                    ? null
                    : () async {
                        setState(() => _isJoining = true);
                        await widget.onJoin();
                        if (mounted) setState(() => _isJoining = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.buttonBlue,
                  minimumSize: Size.zero,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Join',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
    );
  }
}
