import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/chat_message.dart';
import 'widgets/location_preview_card.dart';

class ChatScreen extends StatefulWidget {
  final String jobId;
  final String technicianName;
  final double technicianRating;
  final String categoryTitle;
  final bool isClient;

  const ChatScreen({
    super.key,
    this.jobId = '44444444-4444-4444-4444-444444444444',
    this.technicianName = 'Carlos Benítez',
    this.technicianRating = 4.85,
    this.categoryTitle = 'Electricidad • Disyuntor',
    this.isClient = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _seedInitialMessages();
  }

  void _seedInitialMessages() {
    _messages.addAll([
      ChatMessage(
        id: 'msg-1',
        jobId: widget.jobId,
        senderId: 'sys-0',
        senderName: 'Sistema',
        type: ChatMessageType.system,
        content: '¡Presupuesto aceptado! El chat privado 1:1 está habilitado para coordinar la visita.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        isMine: false,
      ),
      ChatMessage(
        id: 'msg-2',
        jobId: widget.jobId,
        senderId: 'tech-1',
        senderName: widget.technicianName,
        type: ChatMessageType.text,
        content: 'Hola Lucía, buenas tardes. Vi las fotos del tablero. ¿El corte ocurre solo cuando encendés el horno o también con el anafe?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        isMine: false,
      ),
      ChatMessage(
        id: 'msg-3',
        jobId: widget.jobId,
        senderId: 'client-1',
        senderName: 'Lucía Fernández',
        type: ChatMessageType.text,
        content: 'Hola Carlos. Pasa principalmente con el horno, a los 10 minutos de encendido.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        isMine: true,
      ),
      ChatMessage(
        id: 'msg-4',
        jobId: widget.jobId,
        senderId: 'tech-1',
        senderName: widget.technicianName,
        type: ChatMessageType.text,
        content: 'Perfecto, parece una sobrecarga térmica del disyuntor o fuga en la resistencia. Puedo pasar mañana a las 10:00 hs con los repuestos. ¿Me compartís la dirección exacta?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        isMine: false,
      ),
    ]);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final newMsg = ChatMessage.text(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      jobId: widget.jobId,
      senderId: widget.isClient ? 'client-1' : 'tech-1',
      senderName: widget.isClient ? 'Lucía Fernández' : widget.technicianName,
      content: text,
      isMine: true,
    );

    setState(() {
      _messages.add(newMsg);
      _textController.clear();
    });

    _scrollToBottom();
  }

  void _openShareLocationDialog() {
    final addressController = TextEditingController(text: 'Av. Santa Fe 3200');
    final aptController = TextEditingController(text: 'Piso 4, Depto B');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.mustardDark : AppColors.mustardLight).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.share_location_rounded,
                        color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compartir Dirección Exacta',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Visible únicamente para este técnico asignado',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Calle y Número',
                    prefixIcon: Icon(Icons.location_city_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aptController,
                  decoration: const InputDecoration(
                    labelText: 'Piso / Departamento / Notas de timbre',
                    prefixIcon: Icon(Icons.meeting_room_rounded),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _dispatchLocationMessage(
                        address: addressController.text.trim(),
                        aptNotes: aptController.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Confirmar y Enviar Ubicación'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _dispatchLocationMessage({required String address, required String aptNotes}) {
    final locationMsg = ChatMessage.location(
      id: 'loc-${DateTime.now().millisecondsSinceEpoch}',
      jobId: widget.jobId,
      senderId: 'client-1',
      senderName: 'Lucía Fernández',
      latitude: -34.5882,
      longitude: -58.4116,
      address: '$address, Palermo, CABA',
      notes: aptNotes,
      isMine: true,
    );

    setState(() {
      _messages.add(locationMsg);
    });

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              child: const Icon(Icons.person, size: 22, color: AppColors.mustardLight),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.technicianName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 13, color: AppColors.success),
                            SizedBox(width: 3),
                            Text(
                              'Verificado',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: AppColors.accentYellow),
                      const SizedBox(width: 2),
                      Text(
                        '${widget.technicianRating.toStringAsFixed(2)} • ${widget.categoryTitle}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Prominent "Enviar Ubicación Exacta" Action Banner
            if (widget.isClient)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF221F14) : const Color(0xFFFEF9C3),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF3E3618) : const Color(0xFFFDE047),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop_rounded, size: 20, color: AppColors.mustardLight),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Coordinación de visita técnica:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openShareLocationDialog,
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('Enviar Ubicación Exacta', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: isDark ? AppColors.mustardDark : AppColors.mustardLight,
                        foregroundColor: AppColors.pureBlack,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

            // Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageItem(msg, isDark);
                },
              ),
            ),

            // Input Bar
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg, bool isDark) {
    if (msg.type == ChatMessageType.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.content,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    if (msg.type == ChatMessageType.location) {
      return Align(
        alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: LocationPreviewCard(
            latitude: msg.latitude ?? -34.5882,
            longitude: msg.longitude ?? -58.4116,
            address: msg.address ?? 'Dirección',
            notes: msg.notes,
            isMine: msg.isMine,
          ),
        ),
      );
    }

    // Standard text message bubble
    final bubbleColor = msg.isMine
        ? (isDark ? AppColors.mustardDark : AppColors.mustardLight)
        : (isDark ? AppColors.cardDark : AppColors.surfaceLight);
    final textColor = msg.isMine
        ? AppColors.pureBlack
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return Align(
      alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.isMine ? 18 : 4),
            bottomRight: Radius.circular(msg.isMine ? 4 : 18),
          ),
        ),
        child: Text(
          msg.content,
          style: TextStyle(
            color: textColor,
            fontSize: 14.5,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.pureWhite,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          // Explicit location share icon button
          IconButton(
            onPressed: _openShareLocationDialog,
            icon: const Icon(Icons.add_location_alt_rounded),
            color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
            tooltip: 'Enviar ubicación exacta',
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribí un mensaje...',
                filled: true,
                fillColor: isDark ? const Color(0xFF161616) : AppColors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.mustardDark : AppColors.mustardLight,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, size: 20, color: AppColors.pureBlack),
            ),
          ),
        ],
      ),
    );
  }
}
