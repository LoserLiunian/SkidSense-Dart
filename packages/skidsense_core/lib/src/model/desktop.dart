import '../util/json.dart';

// The desktop payload types this app displays, modelled leniently: unknown
// keys are ignored and almost everything is defaulted, because the desktop
// keeps adding fields (its reference types live in `src/shared/ipc.ts`).
// Integers decode from any JSON number, so a fractional `mtimeMs` from
// APFS/ext4/NTFS truncates instead of failing a whole listing (N01, C7).

/// `SessionRow` — `src/store/index-db.ts`.
class SessionRow {
  const SessionRow({
    required this.key,
    this.agent = '',
    this.sessionId = '',
    this.workdir = '',
    this.title = '',
    this.preview = '',
    this.createdAt = 0,
    this.updatedAt = 0,
    this.runState = 'idle',
    this.archived = false,
    this.pinned = false,
    this.backgroundJobs = const [],
  });

  factory SessionRow.fromJson(Map<String, Object?> j) => SessionRow(
        key: j.str('key') ?? '',
        agent: j.str('agent') ?? '',
        sessionId: j.str('sessionId') ?? '',
        workdir: j.str('workdir') ?? '',
        title: j.str('title') ?? '',
        preview: j.str('preview') ?? '',
        createdAt: j.number('createdAt') ?? 0,
        updatedAt: j.number('updatedAt') ?? 0,
        runState: j.str('runState') ?? 'idle',
        archived: j.boolean('archived') ?? false,
        pinned: j.boolean('pinned') ?? false,
        backgroundJobs: j.objects('backgroundJobs', BackgroundJob.fromJson),
      );

  final String key;
  final String agent;
  final String sessionId;
  final String workdir;
  final String title;
  final String preview;
  final int createdAt;
  final int updatedAt;
  final String runState;
  final bool archived;
  final bool pinned;
  final List<BackgroundJob> backgroundJobs;

  Map<String, Object?> toJson() => {
        'key': key,
        'agent': agent,
        'sessionId': sessionId,
        'workdir': workdir,
        'title': title,
        'preview': preview,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'runState': runState,
        'archived': archived,
        'pinned': pinned,
      };
}

class BackgroundJob {
  const BackgroundJob({this.id = '', this.label = '', this.status = '', this.kind, this.endedAt});

  factory BackgroundJob.fromJson(Map<String, Object?> j) => BackgroundJob(
        id: j.str('id') ?? '',
        label: j.str('label') ?? '',
        status: j.str('status') ?? '',
        kind: j.str('kind'),
        endedAt: j.number('endedAt'),
      );

  final String id;
  final String label;
  final String status;
  final String? kind;
  final int? endedAt;
}

class Workspace {
  const Workspace({this.id = '', this.name = '', this.path = '', this.order = 0, this.addedAt = 0});

  factory Workspace.fromJson(Map<String, Object?> j) => Workspace(
        id: j.str('id') ?? '',
        name: j.str('name') ?? '',
        path: j.str('path') ?? '',
        order: j.number('order') ?? 0,
        addedAt: j.number('addedAt') ?? 0,
      );

  final String id;
  final String name;
  final String path;
  final int order;
  final int addedAt;
}

class AgentStatus {
  const AgentStatus({
    this.id = '',
    this.label = '',
    this.driven = false,
    this.installed = false,
    this.binPath,
    this.version,
    this.notes,
    this.tui,
  });

  factory AgentStatus.fromJson(Map<String, Object?> j) => AgentStatus(
        id: j.str('id') ?? '',
        label: j.str('label') ?? '',
        driven: j.boolean('driven') ?? false,
        installed: j.boolean('installed') ?? false,
        binPath: j.str('binPath'),
        version: j.str('version'),
        notes: j.str('notes'),
        tui: j.boolean('tui'),
      );

  final String id;
  final String label;
  final bool driven;
  final bool installed;
  final String? binPath;
  final String? version;
  final String? notes;
  final bool? tui;
}

/// `ModelOption` — `src/agents/models.ts`.
class ModelOption {
  const ModelOption({this.id = '', this.label = '', this.description, this.live = false, this.providerId, this.group});

  factory ModelOption.fromJson(Map<String, Object?> j) => ModelOption(
        id: j.str('id') ?? '',
        label: j.str('label') ?? '',
        description: j.str('description'),
        live: j.boolean('live') ?? false,
        providerId: j.str('providerId'),
        group: j.str('group'),
      );

  final String id;
  final String label;
  final String? description;
  final bool live;

  /// The account row or cloud assignment that serves this model; what
  /// `turn.prompt` takes as `providerId` (spec §7).
  final String? providerId;

  /// Local mode: `account` (the active account's own models) or `other`
  /// (another endpoint of the agent's protocol).
  final String? group;
}

/// Where a harness's calls go right now — `CatalogRoute` in `src/agents/models.ts`.
class CatalogRoute {
  const CatalogRoute({this.kind = 'cli', this.accountId, this.accountName, this.defaultModel});

  factory CatalogRoute.fromJson(Map<String, Object?> j) => CatalogRoute(
        kind: j.str('kind') ?? 'cli',
        accountId: j.str('accountId'),
        accountName: j.str('accountName'),
        defaultModel: j.str('defaultModel'),
      );

  /// `cli`, `official`, `account` or `cloud`.
  final String kind;

  /// The account row in use, for `account`.
  final String? accountId;
  final String? accountName;
  final String? defaultModel;
}

class ModelCatalog {
  const ModelCatalog({this.agent = '', this.models = const [], this.source = 'static', this.route});

  factory ModelCatalog.fromJson(Map<String, Object?> j) => ModelCatalog(
        agent: j.str('agent') ?? '',
        models: j.objects('models', ModelOption.fromJson),
        source: j.str('source') ?? 'static',
        route: j.object('route', CatalogRoute.fromJson),
      );

  final String agent;
  final List<ModelOption> models;
  final String source;
  final CatalogRoute? route;
}

/// `ToolCall` — `src/core/events.ts`. Truncated tool IO arrives as
/// `{"__truncated":true,"bytes":N,"preview":"…"}`.
class ToolCall {
  const ToolCall({
    this.id = '',
    this.name = 'tool',
    this.summary,
    this.input,
    this.result,
    this.status = 'pending',
    this.startedAt = 0,
    this.endedAt,
  });

  factory ToolCall.fromJson(Map<String, Object?> j) => ToolCall(
        id: j.str('id') ?? '',
        name: j.str('name') ?? 'tool',
        summary: j.str('summary'),
        input: j['input'],
        result: j['result'],
        status: j.str('status') ?? 'pending',
        startedAt: j.number('startedAt') ?? 0,
        endedAt: j.number('endedAt'),
      );

  final String id;
  final String name;
  final String? summary;
  final Object? input;
  final Object? result;
  final String status;
  final int startedAt;
  final int? endedAt;
}

class PlanStep {
  const PlanStep({this.text = '', this.status = 'pending'});

  factory PlanStep.fromJson(Map<String, Object?> j) =>
      PlanStep(text: j.str('text') ?? '', status: j.str('status') ?? 'pending');

  final String text;
  final String status;
}

class Plan {
  const Plan({this.explanation, this.steps = const []});

  factory Plan.fromJson(Map<String, Object?> j) =>
      Plan(explanation: j.str('explanation'), steps: j.objects('steps', PlanStep.fromJson));

  final String? explanation;
  final List<PlanStep> steps;
}

class Usage {
  const Usage({
    this.contextTokens,
    this.inputTokens,
    this.outputTokens,
    this.cacheReadTokens,
    this.cacheWriteTokens,
    this.reasoningTokens,
    this.costUsd,
  });

  factory Usage.fromJson(Map<String, Object?> j) => Usage(
        contextTokens: j.number('contextTokens'),
        inputTokens: j.number('inputTokens'),
        outputTokens: j.number('outputTokens'),
        cacheReadTokens: j.number('cacheReadTokens'),
        cacheWriteTokens: j.number('cacheWriteTokens'),
        reasoningTokens: j.number('reasoningTokens'),
        costUsd: j.decimal('costUsd'),
      );

  final int? contextTokens;
  final int? inputTokens;
  final int? outputTokens;
  final int? cacheReadTokens;
  final int? cacheWriteTokens;
  final int? reasoningTokens;
  final double? costUsd;
}

/// `Artifact` in a turn.
class TurnArtifact {
  const TurnArtifact({this.kind = 'file', this.title = '', this.path, this.uri, this.bytes});

  factory TurnArtifact.fromJson(Map<String, Object?> j) => TurnArtifact(
        kind: j.str('kind') ?? 'file',
        title: j.str('title') ?? '',
        path: j.str('path'),
        uri: j.str('uri'),
        bytes: j.number('bytes'),
      );

  final String kind;
  final String title;
  final String? path;
  final String? uri;
  final int? bytes;
}

class SubAgent {
  const SubAgent({
    this.id = '',
    this.callId,
    this.kind,
    this.description,
    this.prompt,
    this.model,
    this.status = 'running',
    this.toolCalls = const [],
    this.text,
    this.textIsLatest,
    this.report,
    this.activity,
    this.durationMs,
    this.totalTokens,
    this.background,
  });

  factory SubAgent.fromJson(Map<String, Object?> j) => SubAgent(
        id: j.str('id') ?? '',
        callId: j.str('callId'),
        kind: j.str('kind'),
        description: j.str('description'),
        prompt: j.str('prompt'),
        model: j.str('model'),
        status: j.str('status') ?? 'running',
        toolCalls: j.objects('toolCalls', ToolCall.fromJson),
        text: j.str('text'),
        textIsLatest: j.boolean('textIsLatest'),
        report: j.str('report'),
        activity: j.str('activity'),
        durationMs: j.number('durationMs'),
        totalTokens: j.number('totalTokens'),
        background: j.boolean('background'),
      );

  final String id;
  final String? callId;
  final String? kind;
  final String? description;

  /// The task it was given.
  final String? prompt;
  final String? model;
  final String status;
  final List<ToolCall> toolCalls;
  final String? text;
  final bool? textIsLatest;
  final String? report;
  final String? activity;
  final int? durationMs;
  final int? totalTokens;
  final bool? background;
}

class WorkflowRun {
  const WorkflowRun({
    this.id = '',
    this.name,
    this.status = 'running',
    this.phases = const [],
    this.agents = const [],
    this.result,
    this.summary,
  });

  factory WorkflowRun.fromJson(Map<String, Object?> j) => WorkflowRun(
        id: j.str('id') ?? '',
        name: j.str('name'),
        status: j.str('status') ?? 'running',
        phases: j.objects('phases', WorkflowPhase.fromJson),
        agents: j.objects('agents', WorkflowAgent.fromJson),
        result: j.str('result'),
        summary: j.str('summary'),
      );

  final String id;
  final String? name;
  final String status;
  final List<WorkflowPhase> phases;
  final List<WorkflowAgent> agents;
  final String? result;
  final String? summary;
}

class WorkflowPhase {
  const WorkflowPhase({this.index = 0, this.title = '', this.status = 'pending'});

  factory WorkflowPhase.fromJson(Map<String, Object?> j) => WorkflowPhase(
        index: j.number('index') ?? 0,
        title: j.str('title') ?? '',
        status: j.str('status') ?? 'pending',
      );

  final int index;
  final String title;
  final String status;
}

class WorkflowAgent {
  const WorkflowAgent({this.id = '', this.label = '', this.status = 'pending', this.model});

  factory WorkflowAgent.fromJson(Map<String, Object?> j) => WorkflowAgent(
        id: j.str('id') ?? '',
        label: j.str('label') ?? '',
        status: j.str('status') ?? 'pending',
        model: j.str('model'),
      );

  final String id;
  final String label;
  final String status;
  final String? model;
}

class ServicedModel {
  const ServicedModel({this.id = '', this.label, this.provider});

  factory ServicedModel.fromJson(Map<String, Object?> j) =>
      ServicedModel(id: j.str('id') ?? '', label: j.str('label'), provider: j.str('provider'));

  final String id;
  final String? label;
  final String? provider;
}

class ModelRoute {
  const ModelRoute({this.requested, this.served, this.rerouted = false});

  factory ModelRoute.fromJson(Map<String, Object?> j) => ModelRoute(
        requested: j.str('requested'),
        served: j.object('served', ServicedModel.fromJson),
        rerouted: j.boolean('rerouted') ?? false,
      );

  final String? requested;
  final ServicedModel? served;
  final bool rerouted;
}

class QueuedPrompt {
  const QueuedPrompt({this.id = '', this.text = '', this.queuedAt = 0});

  factory QueuedPrompt.fromJson(Map<String, Object?> j) =>
      QueuedPrompt(id: j.str('id') ?? '', text: j.str('text') ?? '', queuedAt: j.number('queuedAt') ?? 0);

  final String id;
  final String text;
  final int queuedAt;
}

class Steer {
  const Steer({this.id = '', this.text = '', this.sentAt = 0});

  factory Steer.fromJson(Map<String, Object?> j) =>
      Steer(id: j.str('id') ?? '', text: j.str('text') ?? '', sentAt: j.number('sentAt') ?? 0);

  final String id;
  final String text;
  final int sentAt;
}

class Compaction {
  const Compaction({this.trigger = 'auto', this.atTokens});

  factory Compaction.fromJson(Map<String, Object?> j) =>
      Compaction(trigger: j.str('trigger') ?? 'auto', atTokens: j.number('atTokens'));

  final String trigger;
  final int? atTokens;
}

/// One stretch of a turn, in order — `Segment` in `src/core/snapshot.ts`:
/// `text`/`thinking` start at [from] in the turn's text or reasoning;
/// `tools`/`agents`/`workflows` name their items by [ids].
class Segment {
  const Segment({required this.kind, this.from = 0, this.ids = const []});

  factory Segment.fromJson(Map<String, Object?> j) =>
      Segment(kind: j.str('kind') ?? '', from: j.number('from') ?? 0, ids: j.strings('ids'));

  final String kind;
  final int from;
  final List<String> ids;
}

/// `TurnSnapshot`. Everything but the identity fields is optional-and-defaulted
/// so a turn recorded by an older desktop still parses.
///
/// [json] is the object it was read from. A live patch is applied to that,
/// not to a re-encoding of the fields here, so a field this app does not
/// model survives the patch the way the desktop meant it to.
class TurnSnapshot {
  const TurnSnapshot({
    this.json = const {},
    this.taskId = '',
    this.agent = '',
    this.sessionId,
    this.workdir = '',
    this.phase = 'idle',
    this.prompt = '',
    this.startedAt = 0,
    this.updatedAt = 0,
    this.error,
    this.incomplete = false,
    this.text = '',
    this.reasoning = '',
    this.activity,
    this.segments = const [],
    this.plan,
    this.toolCalls = const [],
    this.subAgents = const [],
    this.workflows = const [],
    this.backgroundJobs = const [],
    this.usage,
    this.artifacts = const [],
    this.interactions = const [],
    this.queued = const [],
    this.compaction,
    this.steers = const [],
    this.modelRoute,
  });

  factory TurnSnapshot.fromJson(Map<String, Object?> j) => TurnSnapshot(
        json: j,
        taskId: j.str('taskId') ?? '',
        agent: j.str('agent') ?? '',
        sessionId: j.str('sessionId'),
        workdir: j.str('workdir') ?? '',
        phase: j.str('phase') ?? 'idle',
        prompt: j.str('prompt') ?? '',
        startedAt: j.number('startedAt') ?? 0,
        updatedAt: j.number('updatedAt') ?? 0,
        error: j.str('error'),
        incomplete: j.boolean('incomplete') ?? false,
        text: j.str('text') ?? '',
        reasoning: j.str('reasoning') ?? '',
        activity: j.str('activity'),
        segments: j.objects('segments', Segment.fromJson),
        plan: j.object('plan', Plan.fromJson),
        toolCalls: j.objects('toolCalls', ToolCall.fromJson),
        subAgents: j.objects('subAgents', SubAgent.fromJson),
        workflows: j.objects('workflows', WorkflowRun.fromJson),
        backgroundJobs: j.objects('backgroundJobs', BackgroundJob.fromJson),
        usage: j.object('usage', Usage.fromJson),
        artifacts: j.objects('artifacts', TurnArtifact.fromJson),
        interactions: j.objects('interactions', Interaction.fromJson),
        queued: j.objects('queued', QueuedPrompt.fromJson),
        compaction: j.object('compaction', Compaction.fromJson),
        steers: j.objects('steers', Steer.fromJson),
        modelRoute: j.object('modelRoute', ModelRoute.fromJson),
      );

  final Map<String, Object?> json;
  final String taskId;
  final String agent;
  final String? sessionId;
  final String workdir;
  final String phase;
  final String prompt;
  final int startedAt;
  final int updatedAt;
  final String? error;
  final bool incomplete;
  final String text;
  final String reasoning;
  final String? activity;
  final List<Segment> segments;
  final Plan? plan;
  final List<ToolCall> toolCalls;
  final List<SubAgent> subAgents;
  final List<WorkflowRun> workflows;
  final List<BackgroundJob> backgroundJobs;
  final Usage? usage;
  final List<TurnArtifact> artifacts;
  final List<Interaction> interactions;
  final List<QueuedPrompt> queued;
  final Compaction? compaction;
  final List<Steer> steers;
  final ModelRoute? modelRoute;

  bool get running => phase == 'starting' || phase == 'running' || phase == 'awaiting-input';

  /// The pending question, if the turn is waiting on one.
  Interaction? get openInteraction {
    for (final interaction in interactions.reversed) {
      if (interaction.answeredAt == null) return interaction;
    }
    return null;
  }
}

/// `Interaction` — `src/core/interaction.ts`.
class Interaction {
  const Interaction({
    this.id = '',
    this.question = const AskUserQuestion(),
    this.askedAt = 0,
    this.answeredAt,
    this.answer,
    this.answeredBy,
  });

  factory Interaction.fromJson(Map<String, Object?> j) => Interaction(
        id: j.str('id') ?? '',
        question: j.object('question', AskUserQuestion.fromJson) ?? const AskUserQuestion(),
        askedAt: j.number('askedAt') ?? 0,
        answeredAt: j.number('answeredAt'),
        answer: j['answer'],
        answeredBy: j.str('answeredBy'),
      );

  final String id;
  final AskUserQuestion question;
  final int askedAt;
  final int? answeredAt;
  final Object? answer;

  /// Which paired device answered, when it was not the desktop.
  final String? answeredBy;
}

class AskUserQuestion {
  const AskUserQuestion({
    this.kind = 'permission',
    this.title = '',
    this.detail,
    this.subject,
    this.choices = const [],
    this.allowFreeText = false,
    this.placeholder,
  });

  factory AskUserQuestion.fromJson(Map<String, Object?> j) => AskUserQuestion(
        kind: j.str('kind') ?? 'permission',
        title: j.str('title') ?? '',
        detail: j.str('detail'),
        subject: j.object('subject', InteractionSubject.fromJson),
        choices: j.objects('choices', AskUserChoice.fromJson),
        allowFreeText: j.boolean('allowFreeText') ?? false,
        placeholder: j.str('placeholder'),
      );

  /// `permission`, `question` or `input`.
  final String kind;
  final String title;
  final String? detail;
  final InteractionSubject? subject;
  final List<AskUserChoice> choices;
  final bool allowFreeText;
  final String? placeholder;
}

class InteractionSubject {
  const InteractionSubject({
    this.type = 'tool',
    this.command,
    this.cwd,
    this.path,
    this.diff,
    this.name,
    this.input,
    this.scopes = const [],
  });

  factory InteractionSubject.fromJson(Map<String, Object?> j) => InteractionSubject(
        type: j.str('type') ?? 'tool',
        command: j.str('command'),
        cwd: j.str('cwd'),
        path: j.str('path'),
        diff: j.str('diff'),
        name: j.str('name'),
        input: j['input'],
        scopes: j.strings('scopes'),
      );

  /// `command`, `fileChange`, `permissions` or `tool`.
  final String type;
  final String? command;
  final String? cwd;
  final String? path;
  final String? diff;
  final String? name;
  final Object? input;
  final List<String> scopes;
}

class AskUserChoice {
  const AskUserChoice({this.id = '', this.label = '', this.description, this.kind = 'neutral'});

  factory AskUserChoice.fromJson(Map<String, Object?> j) => AskUserChoice(
        id: j.str('id') ?? '',
        label: j.str('label') ?? '',
        description: j.str('description'),
        kind: j.str('kind') ?? 'neutral',
      );

  final String id;
  final String label;
  final String? description;

  /// `allow | allow_always | deny | deny_always | neutral`.
  final String kind;
}

/// `TurnRecord` — `src/store/sessions.ts`.
class TurnRecord {
  const TurnRecord({
    this.taskId = '',
    this.prompt = '',
    this.startedAt = 0,
    this.endedAt = 0,
    this.ok = true,
    this.error,
    this.stopReason = '',
    this.snapshot = const TurnSnapshot(),
  });

  factory TurnRecord.fromJson(Map<String, Object?> j) => TurnRecord(
        taskId: j.str('taskId') ?? '',
        prompt: j.str('prompt') ?? '',
        startedAt: j.number('startedAt') ?? 0,
        endedAt: j.number('endedAt') ?? 0,
        ok: j.boolean('ok') ?? true,
        error: j.str('error'),
        stopReason: j.str('stopReason') ?? '',
        snapshot: j.object('snapshot', TurnSnapshot.fromJson) ?? const TurnSnapshot(),
      );

  final String taskId;
  final String prompt;
  final int startedAt;
  final int endedAt;
  final bool ok;
  final String? error;
  final String stopReason;
  final TurnSnapshot snapshot;
}

/// `OpenSessionResponse` — `src/shared/ipc.ts`.
class OpenSessionResponse {
  const OpenSessionResponse({
    this.row = const SessionRow(key: ''),
    this.turns = const [],
    this.live,
    this.origin = 'own',
    this.nativeSessionId,
  });

  factory OpenSessionResponse.fromJson(Map<String, Object?> j) => OpenSessionResponse(
        row: j.object('row', SessionRow.fromJson) ?? const SessionRow(key: ''),
        turns: j.objects('turns', TurnRecord.fromJson),
        live: j.object('live', TurnSnapshot.fromJson),
        origin: j.str('origin') ?? 'own',
        nativeSessionId: j.str('nativeSessionId'),
      );

  final SessionRow row;
  final List<TurnRecord> turns;
  final TurnSnapshot? live;
  final String origin;
  final String? nativeSessionId;
}

/// `PromptResponse`: `{ok:true,…}` or `{ok:false,error}`.
class PromptResponse {
  const PromptResponse({this.ok = false, this.sessionKey, this.taskId, this.error});

  factory PromptResponse.fromJson(Map<String, Object?> j) => PromptResponse(
        ok: j.boolean('ok') ?? false,
        sessionKey: j.str('sessionKey'),
        taskId: j.str('taskId'),
        error: j.str('error'),
      );

  final bool ok;
  final String? sessionKey;
  final String? taskId;
  final String? error;
}

// --- files -------------------------------------------------------------------

/// One directory row — `DirEntry` in `src/shared/ipc.ts`.
class DirEntry {
  const DirEntry({this.name = '', this.path = '', this.kind = 'file', this.size = 0, this.mtime = 0, this.git});

  factory DirEntry.fromJson(Map<String, Object?> j) => DirEntry(
        name: j.str('name') ?? '',
        path: j.str('path') ?? '',
        kind: j.str('kind') ?? 'file',
        size: j.number('size') ?? 0,
        mtime: j.number('mtime') ?? 0,
        git: j.str('git'),
      );

  final String name;
  final String path;

  /// `file`, `dir` or `symlink`.
  final String kind;
  final int size;
  final int mtime;
  final String? git;
}

class ListDirResult {
  const ListDirResult({this.entries = const [], this.truncated = false});

  factory ListDirResult.fromJson(Map<String, Object?> j) =>
      ListDirResult(entries: j.objects('entries', DirEntry.fromJson), truncated: j.boolean('truncated') ?? false);

  final List<DirEntry> entries;
  final bool truncated;
}

class ReadFileResult {
  const ReadFileResult({
    this.path = '',
    this.encoding = 'utf8',
    this.text,
    this.base64,
    this.mime = '',
    this.size = 0,
    this.mtime = 0,
    this.lines = 0,
    this.etag = '',
  });

  factory ReadFileResult.fromJson(Map<String, Object?> j) => ReadFileResult(
        path: j.str('path') ?? '',
        encoding: j.str('encoding') ?? 'utf8',
        text: j.str('text'),
        base64: j.str('base64'),
        mime: j.str('mime') ?? '',
        size: j.number('size') ?? 0,
        mtime: j.number('mtime') ?? 0,
        lines: j.number('lines') ?? 0,
        etag: j.str('etag') ?? '',
      );

  final String path;

  /// `utf8`, `binary` or `too-large`.
  final String encoding;
  final String? text;
  final String? base64;
  final String mime;
  final int size;
  final int mtime;
  final int lines;
  final String etag;
}

/// `{ok, error, conflict}` — the two variants differ only in which fields exist.
class WriteFileResult {
  const WriteFileResult({this.ok = false, this.etag, this.mtime, this.error, this.conflict});

  factory WriteFileResult.fromJson(Map<String, Object?> j) => WriteFileResult(
        ok: j.boolean('ok') ?? false,
        etag: j.str('etag'),
        mtime: j.number('mtime'),
        error: j.str('error'),
        conflict: j.boolean('conflict'),
      );

  final bool ok;
  final String? etag;
  final int? mtime;
  final String? error;
  final bool? conflict;
}

class FileOpResult {
  const FileOpResult({this.ok = false, this.path, this.error});

  factory FileOpResult.fromJson(Map<String, Object?> j) =>
      FileOpResult(ok: j.boolean('ok') ?? false, path: j.str('path'), error: j.str('error'));

  final bool ok;
  final String? path;
  final String? error;
}

// --- git ---------------------------------------------------------------------

class GitFile {
  const GitFile({
    this.path = '',
    this.from,
    this.status = 'modified',
    this.staged = false,
    this.insertions,
    this.deletions,
    this.binary,
  });

  factory GitFile.fromJson(Map<String, Object?> j) => GitFile(
        path: j.str('path') ?? '',
        from: j.str('from'),
        status: j.str('status') ?? 'modified',
        staged: j.boolean('staged') ?? false,
        insertions: j.number('insertions'),
        deletions: j.number('deletions'),
        binary: j.boolean('binary'),
      );

  final String path;
  final String? from;

  /// `modified`, `added`, `deleted`, `renamed`, `untracked`, `conflicted`, `ignored`.
  final String status;
  final bool staged;
  final int? insertions;
  final int? deletions;
  final bool? binary;
}

class GitRepo {
  const GitRepo({
    this.path = '',
    this.branch,
    this.detached = false,
    this.shortSha,
    this.upstream,
    this.ahead = 0,
    this.behind = 0,
    this.defaultBranch,
    this.operation,
    this.empty = false,
  });

  factory GitRepo.fromJson(Map<String, Object?> j) => GitRepo(
        path: j.str('path') ?? '',
        branch: j.str('branch'),
        detached: j.boolean('detached') ?? false,
        shortSha: j.str('shortSha'),
        upstream: j.str('upstream'),
        ahead: j.number('ahead') ?? 0,
        behind: j.number('behind') ?? 0,
        defaultBranch: j.str('defaultBranch'),
        operation: j.str('operation'),
        empty: j.boolean('empty') ?? false,
      );

  final String path;
  final String? branch;
  final bool detached;
  final String? shortSha;
  final String? upstream;
  final int ahead;
  final int behind;
  final String? defaultBranch;
  final String? operation;
  final bool empty;
}

class GitFetchState {
  const GitFetchState({this.lastOkAt, this.lastError, this.pending = false});

  factory GitFetchState.fromJson(Map<String, Object?> j) =>
      GitFetchState(lastOkAt: j.number('lastOkAt'), lastError: j.str('lastError'), pending: j.boolean('pending') ?? false);

  final int? lastOkAt;
  final String? lastError;
  final bool pending;
}

class GitSnapshot {
  const GitSnapshot({
    this.repo,
    this.files = const [],
    this.conflicted = const [],
    this.fetch,
    this.truncated = false,
    this.error,
    this.reason,
  });

  factory GitSnapshot.fromJson(Map<String, Object?> j) => GitSnapshot(
        repo: j.object('repo', GitRepo.fromJson),
        files: j.objects('files', GitFile.fromJson),
        conflicted: j.strings('conflicted'),
        fetch: j.object('fetch', GitFetchState.fromJson),
        truncated: j.boolean('truncated') ?? false,
        error: j.str('error'),
        reason: j.str('reason'),
      );

  final GitRepo? repo;
  final List<GitFile> files;
  final List<String> conflicted;
  final GitFetchState? fetch;
  final bool truncated;
  final String? error;

  /// `not-a-repo` when the workspace has no repository yet.
  final String? reason;
}

class GitHunkLine {
  const GitHunkLine({this.kind = 'context', this.text = '', this.oldLine, this.newLine});

  factory GitHunkLine.fromJson(Map<String, Object?> j) => GitHunkLine(
        kind: j.str('kind') ?? 'context',
        text: j.str('text') ?? '',
        oldLine: j.number('oldLine'),
        newLine: j.number('newLine'),
      );

  /// `context`, `add` or `del`.
  final String kind;
  final String text;
  final int? oldLine;
  final int? newLine;
}

class GitHunk {
  const GitHunk({
    this.header = '',
    this.oldStart = 0,
    this.oldLines = 0,
    this.newStart = 0,
    this.newLines = 0,
    this.lines = const [],
  });

  factory GitHunk.fromJson(Map<String, Object?> j) => GitHunk(
        header: j.str('header') ?? '',
        oldStart: j.number('oldStart') ?? 0,
        oldLines: j.number('oldLines') ?? 0,
        newStart: j.number('newStart') ?? 0,
        newLines: j.number('newLines') ?? 0,
        lines: j.objects('lines', GitHunkLine.fromJson),
      );

  final String header;
  final int oldStart;
  final int oldLines;
  final int newStart;
  final int newLines;
  final List<GitHunkLine> lines;
}

class GitDiffResult {
  const GitDiffResult({
    this.path = '',
    this.binary = false,
    this.hunks = const [],
    this.originalText,
    this.currentText,
    this.truncated = false,
    this.error,
  });

  factory GitDiffResult.fromJson(Map<String, Object?> j) => GitDiffResult(
        path: j.str('path') ?? '',
        binary: j.boolean('binary') ?? false,
        hunks: j.objects('hunks', GitHunk.fromJson),
        originalText: j.str('originalText'),
        currentText: j.str('currentText'),
        truncated: j.boolean('truncated') ?? false,
        error: j.str('error'),
      );

  final String path;
  final bool binary;
  final List<GitHunk> hunks;
  final String? originalText;
  final String? currentText;
  final bool truncated;
  final String? error;
}

class GitBranchInfo {
  const GitBranchInfo({this.name = '', this.current = false, this.remote = false, this.upstream, this.at = 0});

  factory GitBranchInfo.fromJson(Map<String, Object?> j) => GitBranchInfo(
        name: j.str('name') ?? '',
        current: j.boolean('current') ?? false,
        remote: j.boolean('remote') ?? false,
        upstream: j.str('upstream'),
        at: j.number('at') ?? 0,
      );

  final String name;
  final bool current;
  final bool remote;
  final String? upstream;
  final int at;
}

class GitMutateResult {
  const GitMutateResult({this.ok = false, this.error, this.reason, this.detail});

  factory GitMutateResult.fromJson(Map<String, Object?> j) => GitMutateResult(
        ok: j.boolean('ok') ?? false,
        error: j.str('error'),
        reason: j.str('reason'),
        detail: j.str('detail'),
      );

  final bool ok;
  final String? error;
  final String? reason;
  final String? detail;
}

class ArtifactRow {
  const ArtifactRow({
    this.root = '',
    this.path = '',
    this.sessionKey = '',
    this.sessionTitle = '',
    this.agent = '',
    this.at = 0,
    this.edits = 0,
    this.added,
    this.removed,
  });

  factory ArtifactRow.fromJson(Map<String, Object?> j) => ArtifactRow(
        root: j.str('root') ?? '',
        path: j.str('path') ?? '',
        sessionKey: j.str('sessionKey') ?? '',
        sessionTitle: j.str('sessionTitle') ?? '',
        agent: j.str('agent') ?? '',
        at: j.number('at') ?? 0,
        edits: j.number('edits') ?? 0,
        added: j.number('added'),
        removed: j.number('removed'),
      );

  final String root;
  final String path;
  final String sessionKey;
  final String sessionTitle;
  final String agent;
  final int at;
  final int edits;
  final int? added;
  final int? removed;
}

// --- search ------------------------------------------------------------------

/// One file's hits, from `search.progress` (`SearchFileResult` in `src/shared/ipc.ts`).
class SearchFileResult {
  const SearchFileResult({this.path = '', this.matches = const [], this.truncated = false});

  factory SearchFileResult.fromJson(Map<String, Object?> j) => SearchFileResult(
        path: j.str('path') ?? '',
        matches: j.objects('matches', SearchMatch.fromJson),
        truncated: j.boolean('truncated') ?? false,
      );

  final String path;
  final List<SearchMatch> matches;
  final bool truncated;
}

class SearchMatch {
  const SearchMatch({this.line = 0, this.column = 0, this.text = '', this.ranges = const []});

  factory SearchMatch.fromJson(Map<String, Object?> j) => SearchMatch(
        line: j.number('line') ?? 0,
        column: j.number('column') ?? 0,
        text: j.str('text') ?? '',
        ranges: j.objects('ranges', SearchRange.fromJson),
      );

  final int line;
  final int column;

  /// The full line, trimmed of indentation.
  final String text;
  final List<SearchRange> ranges;
}

class SearchRange {
  const SearchRange({this.start = 0, this.end = 0});

  factory SearchRange.fromJson(Map<String, Object?> j) => SearchRange(start: j.number('start') ?? 0, end: j.number('end') ?? 0);

  final int start;
  final int end;
}

/// One `search.progress` message: a flat union of three shapes, `kind` says
/// which (`files`, `done`, `error`).
class SearchProgressPush {
  const SearchProgressPush({
    this.id = '',
    this.kind = '',
    this.files = const [],
    this.done = false,
    this.totalMatches = 0,
    this.truncated = false,
    this.elapsedMs = 0,
    this.fileCount = 0,
    this.error = '',
  });

  factory SearchProgressPush.fromJson(Map<String, Object?> j) => SearchProgressPush(
        id: j.str('id') ?? '',
        kind: j.str('kind') ?? '',
        files: j.objects('files', SearchFileResult.fromJson),
        done: j.boolean('done') ?? false,
        totalMatches: j.number('totalMatches') ?? 0,
        truncated: j.boolean('truncated') ?? false,
        elapsedMs: j.number('elapsedMs') ?? 0,
        fileCount: j.number('fileCount') ?? 0,
        error: j.str('error') ?? '',
      );

  final String id;
  final String kind;
  final List<SearchFileResult> files;
  final bool done;
  final int totalMatches;
  final bool truncated;
  final int elapsedMs;
  final int fileCount;
  final String error;
}

// --- live turn ---------------------------------------------------------------

/// `SessionPatchPush` — `src/shared/ipc.ts`.
class SessionPatchPush {
  const SessionPatchPush({
    this.sessionKey = '',
    this.taskId = '',
    this.seq = 0,
    this.fromSeq = 0,
    this.patch = const SnapshotPatch(),
    this.base,
  });

  factory SessionPatchPush.fromJson(Map<String, Object?> j) => SessionPatchPush(
        sessionKey: j.str('sessionKey') ?? '',
        taskId: j.str('taskId') ?? '',
        seq: j.number('seq') ?? 0,
        fromSeq: j.number('fromSeq') ?? 0,
        patch: j.object('patch', SnapshotPatch.fromJson) ?? const SnapshotPatch(),
        base: j.object('base', TurnSnapshot.fromJson),
      );

  final String sessionKey;
  final String taskId;
  final int seq;
  final int fromSeq;
  final SnapshotPatch patch;
  final TurnSnapshot? base;
}

/// The wire patch: deltas for the two append-only fields, wholesale for the rest.
class SnapshotPatch {
  const SnapshotPatch({this.textDelta, this.reasoningDelta, this.fields});

  factory SnapshotPatch.fromJson(Map<String, Object?> j) =>
      SnapshotPatch(textDelta: j.str('textDelta'), reasoningDelta: j.str('reasoningDelta'), fields: j.obj('fields'));

  final String? textDelta;
  final String? reasoningDelta;
  final Map<String, Object?>? fields;
}
