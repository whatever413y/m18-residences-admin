import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_bloc.dart';
import 'package:m18_residences_admin/features/auth/auth_event.dart';
import 'package:m18_residences_admin/features/room/bloc/room_bloc.dart';
import 'package:m18_residences_admin/features/room/bloc/room_event.dart';
import 'package:m18_residences_admin/features/room/bloc/room_state.dart';
import 'package:m18_residences_admin/features/room/widgets/room_card.dart';
import 'package:m18_residences_admin/features/room/widgets/room_form_dialog.dart';
import 'package:m18_residences_admin/utils/admin_app_bar.dart';
import 'package:m18_residences_admin/utils/confirmation_action.dart';
import 'package:m18_residences_admin/utils/custom_add_button.dart';
import 'package:m18_residences_admin/utils/entity_card.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  late AuthBloc authBloc;
  late RoomBloc roomBloc;

  @override
  void initState() {
    super.initState();
    authBloc = context.read<AuthBloc>();
    roomBloc = context.read<RoomBloc>();
  }

  Future<void> _showRoomDialog({Room? room}) async {
    final result = await showAppModal<Map<String, dynamic>?>(context, builder: (_) => RoomFormDialog(room: room));

    if (!mounted) return;
    if (result == null) return;

    final request = RoomRequest(name: result['name'] as String, rent: result['rent'] as int);

    // Replaced by the bloc's result (see the listener).
    AppToast.show(context, room != null ? 'Saving room...' : 'Adding room...', type: ToastType.loading);
    if (room != null) {
      roomBloc.add(UpdateRoom(room.id, request));
    } else {
      roomBloc.add(AddRoom(request));
    }
  }

  Future<void> _confirmDelete(Room room) async {
    await showConfirmationAction(
      context: context,
      title: 'Delete ${room.name}?',
      message: "This can't be undone. A room that still has tenants or readings can't be deleted.",
      confirmLabel: 'Delete room',
      onConfirmed: () async {
        await _deleteRoom(room.id);
      },
    );
  }

  Future<void> _deleteRoom(int id) async {
    final completer = Completer<void>();

    roomBloc.add(DeleteRoom(id, onComplete: completer));

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminAppBar(title: 'Rooms', onRefresh: () => roomBloc.add(LoadRooms())),
      body: BlocListener<RoomBloc, RoomState>(
        listener: (context, state) {
          if (state is RoomActionFailed) {
            AppToast.show(context, state.message, type: ToastType.error);
          } else if (state is RoomError) {
            // A failed load may mean the session expired; the auth check then shows the login error.
            authBloc.add(CheckAuthStatus());
          } else if (state is AddSuccess) {
            AppToast.show(context, 'Room created', type: ToastType.success);
          } else if (state is UpdateSuccess) {
            AppToast.show(context, 'Room updated', type: ToastType.success);
          } else if (state is DeleteSuccess) {
            AppToast.show(context, 'Room deleted', type: ToastType.success);
          }
        },
        child: BlocBuilder<RoomBloc, RoomState>(
          // Only data loads change what the page shows; action results are reported by the listener.
          buildWhen: (_, state) => state is RoomInitial || state is RoomLoading || state is RoomLoaded || state is RoomError,
          builder: (context, state) {
            if (state is RoomLoading || state is RoomInitial) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is RoomError) {
              return ErrorView(message: state.message, onRetry: () => roomBloc.add(LoadRooms()));
            } else if (state is RoomLoaded) {
              final rooms = state.rooms;

              if (rooms.isEmpty) {
                return const EmptyState(icon: Icons.meeting_room_outlined, title: 'No rooms yet', message: 'Add a room with New Room.');
              }

              return ResponsiveCenter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RefreshIndicator(
                    onRefresh: () async {
                      roomBloc.add(LoadRooms());
                      await roomBloc.stream.firstWhere((state) => state is! RoomLoading);
                    },
                    child: !context.windowSize.isCompact
                        ? GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            // A fixed height that fits the card (two icon buttons), whatever the column width.
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 420,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: EntityCard.gridExtent,
                            ),
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final room = rooms[index];
                              return RoomCard(
                                room: room,
                                onEdit: () => _showRoomDialog(room: room),
                                onDelete: () => _confirmDelete(room),
                              );
                            },
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: rooms.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final room = rooms[index];
                              return RoomCard(
                                room: room,
                                onEdit: () => _showRoomDialog(room: room),
                                onDelete: () => _confirmDelete(room),
                              );
                            },
                          ),
                  ),
                ),
              );
            }

            return const SizedBox();
          },
        ),
      ),
      floatingActionButton: CustomAddButton(onPressed: () => _showRoomDialog(), label: 'New Room'),
    );
  }
}
