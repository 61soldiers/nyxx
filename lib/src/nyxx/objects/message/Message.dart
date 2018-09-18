part of nyxx;

/// [Message] class represents single message. It contains it's Event [Stream]s.
/// [Message] among all it's poperties has also backreference to [Channel] from which it was sent, [Guild] and [User] which sent this message.
/// Supports sending files via `sendFile()` - method can send file or file and use it in embed. Read how to use it [here](https://github.com/l7ssha/nyxx/wiki/Embeds)
class Message extends SnowflakeEntity {
  StreamController<MessageUpdateEvent> _onUpdate;
  StreamController<MessageDeleteEvent> _onDelete;
  StreamController<MessageReactionEvent> _onReactionAdded;
  StreamController<MessageReactionEvent> _onReactionRemove;
  StreamController<MessageReactionsRemovedEvent> _onReactionsRemoved;

  /// The raw object returned by the API.
  //Map<String, dynamic> raw;

  /// The message's content.
  String content;

  /// The message's nonce, null if not set.
  String nonce;

  /// The timestamp of when the message was last edited, null if not edited.
  DateTime editedTimestamp;

  /// Channel in which message was sent
  MessageChannel channel;

  /// The message's guild.
  Guild guild;

  /// The message's author. Can be instance of member
  User author;

  /// The mentions in the message.
  Map<Snowflake, User> mentions;

  /// A list of IDs for the role mentions in the message.
  Map<Snowflake, Role> roleMentions;

  /// A collection of the embeds in the message.
  Map<String, Embed> embeds;

  /// The attachments in the message.
  Map<Snowflake, Attachment> attachments;

  /// Whether or not the message is pinned.
  bool pinned;

  /// Whether or not the message was sent with TTS enabled.
  bool tts;

  /// Whether or @everyone was mentioned in the message.
  bool mentionEveryone;

  /// List of message reactions
  List<Reaction> reactions;

  /// Emitted when the message is edited.
  Stream<MessageUpdateEvent> onUpdate;

  /// Emitted when the message is deleted.
  Stream<MessageDeleteEvent> onDelete;

  /// Emitted when a user adds a reaction to a message.
  Stream<MessageReactionEvent> onReactionAdded;

  /// Emitted when a user adds a reaction to a message.
  Stream<MessageReactionEvent> onReactionRemove;

  /// Emitted when a user explicitly removes all reactions from a message.
  Stream<MessageReactionsRemovedEvent> onReactionsRemoved;

  /// Returns url to this message.
  String get url => "https://discordapp.com/channels/${this.guild.id.toString()}"
      "/${this.channel.id.toString()}/${this.id.toString()}";

  Message._new(Map<String, dynamic> raw) : super(Snowflake(raw['id'] as String)) {
    this._onUpdate = StreamController.broadcast();
    this.onUpdate = this._onUpdate.stream;

    this._onDelete = StreamController.broadcast();
    this.onDelete = this._onDelete.stream;

    this._onReactionRemove = StreamController.broadcast();
    this.onReactionRemove = this._onReactionRemove.stream;

    this._onReactionAdded = StreamController.broadcast();
    this.onReactionAdded = this._onReactionAdded.stream;

    this._onReactionsRemoved = StreamController.broadcast();
    this.onReactionsRemoved = this._onReactionsRemoved.stream;

    this.content = raw['content'] as String;
    this.nonce = raw['nonce'] as String;

    this.channel = _client.channels[Snowflake(raw['channel_id'] as String)]
        as MessageChannel;

    this.pinned = raw['pinned'] as bool;
    this.tts = raw['tts'] as bool;
    this.mentionEveryone = raw['mention_everyone'] as bool;

    this.channel._cacheMessage(this);
    this.channel.lastMessageID = this.id;

    this.guild = _client.guilds[Snowflake(raw['guild_id'] as String)];
    if (this.guild != null) {
      this.author =
          this.guild.members[Snowflake(raw['author']['id'] as String)];

      if (this.author == null) {
        this.author = _client.users[Snowflake(raw['author']['id'] as String)];

        if(this.author == null) {
          this.author = User._new(raw['author'] as Map<String, dynamic>);
          _client.users[author.id] = author;
        }
      }

      if (raw['mention_roles'] != null) {
        this.roleMentions = Map<Snowflake, Role>();
        raw['mention_roles'].forEach((o) {
          var s = Snowflake(o as String);
          this.roleMentions[s] = guild.roles[s];
        });
      }
    }

    if (raw['edited_timestamp'] != null)
      this.editedTimestamp = DateTime.parse(raw['edited_timestamp'] as String);

    this.mentions = Map<Snowflake, Member>();
    raw['mentions'].forEach((o) {
      final user = Member._reverse(o as Map<String, dynamic>, this.guild);
      this.mentions[user.id] = user;
    });

    this.embeds = Map<String, Embed>();
    raw['embeds'].forEach((o) {
      Embed embed = Embed._new( o as Map<String, dynamic>);
      this.embeds[embed.title] = embed;
    });

    this.attachments = Map<Snowflake, Attachment>();
    raw['attachments'].forEach((o) {
      final Attachment attachment =
          Attachment._new( o as Map<String, dynamic>);
      this.attachments[attachment.id] = attachment;
    });

    this.reactions = List<Reaction>();
    if (raw['reactions'] != null) {
      raw['reactions'].forEach((o) {
        this.reactions.add(Reaction._new(o as Map<String, dynamic>));
      });
    }
  }

  /// Returns mention of message
  @override
  String toString() => this.content;

  /// Edits the message.
  ///
  /// Throws an [Exception] if the HTTP request errored.
  ///     Message.edit("My edited content!");
  Future<Message> edit(
      {String content,
      EmbedBuilder embed,
      bool tts = false,
      bool disableEveryone}) async {
    if(this.id != _client.self.id)
      return null;

    String newContent;
    if (content != null &&
        (disableEveryone == true ||
            (disableEveryone == null &&
                _client._options.disableEveryone))) {
      newContent = content
          .replaceAll("@everyone", "@\u200Beveryone")
          .replaceAll("@here", "@\u200Bhere");
    } else {
      newContent = content;
    }

    final HttpResponse r = await _client.http.send(
        'PATCH', '/channels/${this.channel.id}/messages/${this.id}',
        body: <String, dynamic>{
          "content": newContent,
          "embed": (embed != null ? embed._build() : "")
        });
    return Message._new( r.body as Map<String, dynamic>);
  }

  /// Add reaction to message.
  Future<void> createReaction(Emoji emoji) async {
    await _client.http.send('PUT',
        "/channels/${this.channel.id}/messages/${this.id}/reactions/${emoji.encode()}/@me");
  }

  /// Deletes reaction of bot. Emoji as ':emoji_name:'
  Future<void> deleteReaction(Emoji emoji) async {
    await _client.http.send('DELETE',
        "/channels/${this.channel.id}/messages/${this.id}/reactions/${emoji.encode()}/@me");
  }

  /// Deletes reaction of given user.
  Future<void> deleteUserReaction(Emoji emoji, String userId) async {
    await _client.http.send('DELETE',
        "/channels/${this.channel.id}/messages/${this.id}/reactions/${emoji.encode()}/$userId");
  }

  /// Deletes all reactions
  Future<void> deleteAllReactions() async {
    await _client.http.send(
        'DELETE', "/channels/${this.channel.id}/messages/${this.id}/reactions");
  }

  /// Deletes the message.
  ///
  /// Throws an [Exception] if the HTTP request errored.
  Future<void> delete({String auditReason = ""}) async {
    await _client.http.send(
        'DELETE', '/channels/${this.channel.id}/messages/${this.id}',
        reason: auditReason);
  }

  /// Pins [Message] in current [Channel]
  Future<void> pinMessage() async {
    await _client.http.send('PUT', "/channels/${channel.id}/pins/$id");
  }

  /// Unpins [Message] in current [Channel]
  Future<void> unpinMessage() async {
    await _client.http.send('DELETE', "/channels/${channel.id}/pins/$id");
  }
}
