// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'SkidSense';

  @override
  String get ok => '好';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重试';

  @override
  String get back => '返回';

  @override
  String get close => '关闭';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get refresh => '刷新';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get done => '完成';

  @override
  String get edit => '编辑';

  @override
  String get preview => '预览';

  @override
  String get reload => '重新加载';

  @override
  String get more => '更多';

  @override
  String get search => '搜索';

  @override
  String get clear => '清除';

  @override
  String get create => '创建';

  @override
  String get continueAction => '继续';

  @override
  String get dismiss => '关闭';

  @override
  String get none => '—';

  @override
  String get loginTitle => '登录';

  @override
  String get loginSubtitle => '用与电脑端 SkidSense 相同的账号登录——两端靠它找到彼此。';

  @override
  String get serverAddress => '服务器';

  @override
  String serverAddressUsed(String address) {
    return '将使用 $address';
  }

  @override
  String get serverAddressInvalid => '请输入服务器地址，例如 https://example.com';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get signIn => '登录';

  @override
  String get testConnection => '测试连接';

  @override
  String serverReachable(String name) {
    return '服务器可用：$name';
  }

  @override
  String get captchaTitle => '人机验证';

  @override
  String get captchaPassed => '已通过验证';

  @override
  String get captchaRedo => '重新验证';

  @override
  String captchaFailed(String code) {
    return '验证失败（$code），请重试。';
  }

  @override
  String get captchaExpired => '验证已过期，请重试。';

  @override
  String get captchaOnSignIn => '登录时会弹出人机验证。';

  @override
  String get captchaLoading => '正在加载人机验证…';

  @override
  String get captchaLoadFailed => '人机验证加载失败';

  @override
  String get captchaLoadFailedHint => '请检查网络连接，然后重试。';

  @override
  String get passwordLoginDisabled => '这个服务器关闭了密码登录。';

  @override
  String get pairingAfterLogin => '登录与配对是两步：先在这里登录，再扫描电脑上的二维码。';

  @override
  String get twoFactorTitle => '两步验证';

  @override
  String get twoFactorHint => '输入验证器里的 6 位验证码，或一枚备用码。';

  @override
  String get twoFactorRequired => '这个账号需要二次验证。';

  @override
  String twoFactorMethods(String methods) {
    return '可用方式：$methods';
  }

  @override
  String get verificationCode => '验证码';

  @override
  String get verify => '验证';

  @override
  String get twoFactorPasskeyOnly =>
      '这个账号的二次验证是通行密钥（Passkey），App 暂不支持。请先在网页端开启两步验证并绑定验证器 App，再回到这里用它的验证码登录。';

  @override
  String get hostsTitle => '我的电脑';

  @override
  String signedInAs(String user, String server) {
    return '$user · $server';
  }

  @override
  String get pairComputer => '配对电脑';

  @override
  String get pairedSection => '已配对';

  @override
  String get pairedSectionHint => '可以直接连接';

  @override
  String get otherHostsSection => '这个账号的其他电脑';

  @override
  String get otherHostsHint => '还没有和这台手机配对';

  @override
  String get presenceOnline => '在线';

  @override
  String get presenceRelayOffline => '中继离线';

  @override
  String get presenceOffline => '离线';

  @override
  String get presenceRelayOfflineHint => '没有连到中继——在局域网里仍可能连得上。';

  @override
  String get fingerprint => '指纹';

  @override
  String get lanAddresses => '局域网';

  @override
  String get connect => '连接';

  @override
  String get forget => '忘记';

  @override
  String forgetTitle(String name) {
    return '忘记「$name」？';
  }

  @override
  String get forgetBody => '会同时在服务器上撤销这台手机：电脑立即断开它，也不再为它加密历史。之后要重新扫码才能再连。';

  @override
  String get forgetAction => '忘记并撤销';

  @override
  String get noComputersTitle => '还没有电脑';

  @override
  String get noComputersBody => '在电脑端 SkidSense 里打开「远程控制」并生成配对二维码，再回到这里扫描。';

  @override
  String get hostNeedsQr => '在它上面生成二维码即可配对';

  @override
  String get loadingHosts => '正在读取电脑列表…';

  @override
  String get settings => '设置';

  @override
  String get pairingTitle => '配对电脑';

  @override
  String get pairingIntro =>
      '在电脑端 SkidSense 打开「远程控制」，扫描窗口里的二维码。二维码只能用一次，10 分钟内有效。';

  @override
  String get scanQr => '扫描二维码';

  @override
  String get pasteLinkSection => '或者粘贴配对链接';

  @override
  String get pasteLinkLabel => 'skidsense://pair/1?d=…';

  @override
  String get readLink => '读取链接';

  @override
  String get confirmComputer => '是这台电脑吗？';

  @override
  String get machineName => '名称';

  @override
  String get backend => '服务器';

  @override
  String get fingerprintCheck => '请与电脑屏幕上显示的指纹逐组核对。不一致就说明这个二维码不是你正在用的那台电脑。';

  @override
  String get confirmPair => '配对';

  @override
  String get pairStepRegistering => '正在登记这台手机…';

  @override
  String get pairStepAlreadyRegistered => '这台手机已经登记过，正在重新连接…';

  @override
  String get pairStepHandshaking => '正在与电脑握手…';

  @override
  String get pairStepRepairing => '电脑上没有这台手机的记录，正在重新配对…';

  @override
  String get pairStepFinishing => '配对完成，正在读取这台手机被授予的权限…';

  @override
  String pairStepTrying(String route) {
    return '正在尝试$route…';
  }

  @override
  String get cameraUnavailable => '相机不可用。请改为粘贴配对链接。';

  @override
  String get scannerPrompt => '把电脑上的二维码放进取景框';

  @override
  String get scannerTorch => '手电筒';

  @override
  String get notAPairingCode => '这不是 SkidSense 的配对二维码。';

  @override
  String get tabSessions => '会话';

  @override
  String get tabFiles => '文件';

  @override
  String get tabGit => 'Git';

  @override
  String get tabHistory => '历史';

  @override
  String routeLan(String address) {
    return '局域网 $address';
  }

  @override
  String get routeRelay => '中继';

  @override
  String statusConnected(String route) {
    return '已连接 · $route';
  }

  @override
  String statusConnectedLimited(String route, int rate) {
    return '已连接 · $route（限速 $rate KB/s）';
  }

  @override
  String statusConnecting(String route) {
    return '正在连接 · $route';
  }

  @override
  String get statusAuthorizing => '正在连接 · 获取授权';

  @override
  String statusWaiting(String error, int seconds) {
    return '$error · $seconds 秒后重试';
  }

  @override
  String statusFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get statusIdle => '未连接';

  @override
  String get offlineTitle => '还没有连上电脑';

  @override
  String get offlineBody => '确认电脑上的 SkidSense 正在运行，且这台手机与它配对过。局域网不可用时会自动走中继。';

  @override
  String get backToComputers => '电脑';

  @override
  String get searchSessions => '搜索会话';

  @override
  String get noSessionsTitle => '还没有会话';

  @override
  String get noSessionsBody => '在电脑上开始一个，或者在这里新建。';

  @override
  String get noSessionsNoPrompt => '这台手机不能新建会话。';

  @override
  String noSearchResults(String query) {
    return '没有与「$query」匹配的会话';
  }

  @override
  String get newSession => '新建会话';

  @override
  String get workspace => '工作区';

  @override
  String get agent => '代理';

  @override
  String get titleOptional => '标题（可留空）';

  @override
  String get renameSession => '重命名会话';

  @override
  String get sessionTitle => '标题';

  @override
  String deleteSessionTitle(String title) {
    return '删除「$title」？';
  }

  @override
  String get deleteSessionBody => '会话和它的记录会在电脑上删除。';

  @override
  String backgroundJobs(int count) {
    return '$count 个后台任务';
  }

  @override
  String get loadingSessions => '正在读取会话…';

  @override
  String get runStateRunning => '运行中';

  @override
  String get runStateAwaiting => '等你回应';

  @override
  String get runStateStarting => '启动中';

  @override
  String get runStateIdle => '空闲';

  @override
  String get runStateDone => '已完成';

  @override
  String get runStateError => '失败';

  @override
  String get runStateAborted => '已停止';

  @override
  String get runStatePending => '等待中';

  @override
  String get runStateCancelled => '已取消';

  @override
  String updatedAgo(String ago) {
    return '$ago更新';
  }

  @override
  String get openingSession => '正在打开会话…';

  @override
  String get sessionNotFound => '电脑上没有这个会话。';

  @override
  String get openTerminal => '终端';

  @override
  String get openFiles => '文件';

  @override
  String get openGit => 'Git';

  @override
  String get approvalPermission => '需要你的许可';

  @override
  String get approvalQuestion => '代理在提问';

  @override
  String get approvalInput => '代理在等输入';

  @override
  String get approvalOther => '代理需要回应';

  @override
  String get approvalFreeText => '可自由回答';

  @override
  String approvalCwd(String cwd) {
    return '工作目录：$cwd';
  }

  @override
  String approvalScopes(String scopes) {
    return '请求的权限：$scopes';
  }

  @override
  String get approvalNoPermission => '这台手机没有审批权限。请在电脑上回应，或换一台有权限的设备。';

  @override
  String approvalAnsweredElsewhere(String device) {
    return '已在「$device」上回应';
  }

  @override
  String get allow => '允许';

  @override
  String get deny => '拒绝';

  @override
  String get sendAnswer => '发送回答';

  @override
  String get skip => '跳过';

  @override
  String get cancelTurn => '取消回合';

  @override
  String get answerPlaceholder => '你的回答';

  @override
  String get toolInput => '输入';

  @override
  String get toolResult => '结果';

  @override
  String toolTruncated(String label, String size) {
    return '$label已截断（原始 $size）';
  }

  @override
  String get messageHint => '说点什么';

  @override
  String get steerHint => '追加到正在进行的回合';

  @override
  String get send => '发送';

  @override
  String get steer => '插话';

  @override
  String get stop => '停止';

  @override
  String get composerOptions => '选项';

  @override
  String get attach => '添加附件';

  @override
  String get attachmentsNote => '附件会随下一条消息发送；离开这个会话就会丢弃。';

  @override
  String get remove => '移除';

  @override
  String get noPromptPermission => '这台手机没有发消息的权限。';

  @override
  String get options => '发送选项';

  @override
  String get model => '模型';

  @override
  String get modelDefault => '默认';

  @override
  String get noModels => '没有可选的模型列表';

  @override
  String modelDefaultNamed(String model) {
    return '默认（$model）';
  }

  @override
  String get composerModelsLoading => '正在读取模型…';

  @override
  String get composerRouteCloud => '云端：经由你的第一方账号';

  @override
  String composerRouteAccount(String account) {
    return '本地账号：$account';
  }

  @override
  String get composerRouteOfficial => '本地：Anthropic 官方订阅（强制）';

  @override
  String get composerRouteCli => '本地：使用代理自己的配置';

  @override
  String get composerAccount => '账号';

  @override
  String composerAccountHint(String agent) {
    return '在电脑上设置：$agent 的所有对话从下一个回合起都使用它。';
  }

  @override
  String get composerModelsCloud => '云端模型';

  @override
  String composerModelsAccount(String account) {
    return '$account 的模型';
  }

  @override
  String get composerModelsCli => 'CLI 自身的模型';

  @override
  String get composerModelsOtherAccounts => '其他账号（仅本次对话）';

  @override
  String get composerModelsOtherEndpoints => '其他端点（仅本次对话）';

  @override
  String get composerModelsOtherHint => '只有这个对话使用它，电脑上设置的账号不变。';

  @override
  String get composerCloudEmptyTitle => '云端还没有模型';

  @override
  String get composerCloudEmptyBody => '云端模式只提供从云端 Key 分配给这个代理的模型。';

  @override
  String get composerOpenModels => '到「模型」分配';

  @override
  String get slashTitle => '命令';

  @override
  String slashCount(int count) {
    return '$count 个命令';
  }

  @override
  String get slashLoading => '正在读取命令…';

  @override
  String get slashSourceBuiltin => '内置';

  @override
  String get slashSourceCommand => '命令';

  @override
  String get slashSourceSkill => '技能';

  @override
  String get slashScopeWorkspace => '本工作区';

  @override
  String get slashScopeGlobal => '全局';

  @override
  String slashAliases(String names) {
    return '别名 $names';
  }

  @override
  String get effort => '思考强度';

  @override
  String get effortMinimal => '最低';

  @override
  String get effortLow => '低';

  @override
  String get effortMedium => '中';

  @override
  String get effortHigh => '高';

  @override
  String get effortXhigh => '很高';

  @override
  String get effortMax => '最高';

  @override
  String get effortUltra => '极致';

  @override
  String get approvalMode => '审批方式';

  @override
  String get approvalModeLocked => '审批方式（这台手机没有审批权限，只能用默认）';

  @override
  String get approvalDefault => '每次询问';

  @override
  String get approvalAcceptEdits => '自动接受编辑';

  @override
  String get approvalPlan => '仅计划';

  @override
  String get approvalDontAsk => '不再询问';

  @override
  String get approvalBypass => '绕过全部权限';

  @override
  String get thinking => '思考过程';

  @override
  String get plan => '计划';

  @override
  String get backgroundTasks => '后台任务';

  @override
  String usageContext(String tokens) {
    return '上下文 $tokens';
  }

  @override
  String usageOutput(String tokens) {
    return '输出 $tokens';
  }

  @override
  String steered(String text) {
    return '插话：$text';
  }

  @override
  String get compactedAuto => '上下文已自动压缩';

  @override
  String get compactedManual => '上下文已压缩';

  @override
  String get subAgent => '子代理';

  @override
  String get subAgentTask => '任务';

  @override
  String get subAgentLatest => '最近发言';

  @override
  String get subAgentReport => '结果';

  @override
  String get workflow => '工作流';

  @override
  String toolCalls(int count) {
    return '$count 次工具调用';
  }

  @override
  String promptRefused(String reason) {
    return '电脑没有接受这条消息：$reason';
  }

  @override
  String get promptRefusedPlain => '电脑没有接受这条消息。';

  @override
  String get promptUncertain => '没有收到回应——回合可能已经开始。请先查看会话记录，再决定是否重发。';

  @override
  String get promptUncertainDropped =>
      '没有收到回应——回合可能已经开始。请先查看会话记录，再决定是否重发；附件已移除，需要重新添加。';

  @override
  String uploadIncomplete(String name) {
    return '「$name」还没传完。';
  }

  @override
  String uploading(String name) {
    return '正在上传 $name';
  }

  @override
  String get jumpToLatest => '最新';

  @override
  String get you => '你';

  @override
  String get filesTitle => '文件';

  @override
  String get searchContent => '搜索文件内容';

  @override
  String get regex => '正则';

  @override
  String get searching => '正在搜索…';

  @override
  String searchSummary(int matches, int files) {
    return '$files 个文件中 $matches 处匹配';
  }

  @override
  String get searchCancelled => '搜索已停止';

  @override
  String get searchInterrupted => '连接中断，搜索已停止，请重新搜索。';

  @override
  String moreMatches(int count) {
    return '还有 $count 处';
  }

  @override
  String get dirTruncated => '这个目录的项目太多，只显示了一部分。';

  @override
  String get emptyDir => '这里是空的';

  @override
  String get showIgnored => '显示被忽略的文件';

  @override
  String get binaryFile => '这是二进制文件，只能预览。';

  @override
  String get tooLargeFile => '文件太大，无法在这里打开。';

  @override
  String fileLines(int count, String size) {
    return '$count 行 · $size';
  }

  @override
  String get saved => '已保存';

  @override
  String get saveConflict => '文件在别处被改过，为避免覆盖，保存被拒绝。请重新加载后再改。';

  @override
  String get unsavedChanges => '放弃你的修改？';

  @override
  String get discard => '放弃';

  @override
  String get newFile => '新建文件';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get name => '名称';

  @override
  String deleteItemTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String get deleteItemBody => '它会在电脑上被删除。';

  @override
  String get noWorkspace => '没有工作区';

  @override
  String get chooseWorkspace => '工作区';

  @override
  String get root => '根目录';

  @override
  String get gitTitle => 'Git';

  @override
  String get notARepo => '这个工作区还不是 Git 仓库。';

  @override
  String get initRepo => '在这里初始化仓库';

  @override
  String get branch => '分支';

  @override
  String detached(String sha) {
    return '游离于 $sha';
  }

  @override
  String upstream(String name) {
    return '上游 $name';
  }

  @override
  String aheadBehind(int ahead, int behind) {
    return '↑$ahead ↓$behind';
  }

  @override
  String get branches => '分支';

  @override
  String get fetch => '获取';

  @override
  String get pull => '拉取';

  @override
  String get push => '推送';

  @override
  String get switchBranch => '切换';

  @override
  String get currentBranch => '当前';

  @override
  String get remoteBranch => '远程';

  @override
  String get changes => '改动';

  @override
  String get staged => '已暂存';

  @override
  String get unstaged => '未暂存';

  @override
  String get noChanges => '没有可提交的改动';

  @override
  String get stage => '暂存';

  @override
  String get unstage => '取消暂存';

  @override
  String get stageAll => '全部暂存';

  @override
  String get discardChanges => '丢弃改动';

  @override
  String discardTitle(String path) {
    return '丢弃对 $path 的改动？';
  }

  @override
  String get discardBody => '这些改动会在电脑上丢失。';

  @override
  String get commit => '提交';

  @override
  String get commitMessage => '提交说明';

  @override
  String get commitStaged => '提交已暂存的改动';

  @override
  String get committed => '已提交';

  @override
  String renamedFrom(String path) {
    return '来自 $path';
  }

  @override
  String get diffTruncated => '差异太大，只显示了一部分。';

  @override
  String get binaryDiff => '二进制文件';

  @override
  String get gitModified => '已修改';

  @override
  String get gitAdded => '新增';

  @override
  String get gitDeleted => '已删除';

  @override
  String get gitRenamed => '重命名';

  @override
  String get gitUntracked => '未跟踪';

  @override
  String get gitConflicted => '冲突';

  @override
  String get gitIgnored => '已忽略';

  @override
  String gitOperationFailed(String message) {
    return 'Git：$message';
  }

  @override
  String conflictsBanner(int count) {
    return '$count 个文件有冲突';
  }

  @override
  String get terminalTitle => '终端';

  @override
  String get terminalWarningTitle => '终端会绕过审批';

  @override
  String get terminalWarningBody =>
      '终端里跑的是电脑上真正的 CLI。权限提示由它自己在终端里回应，手机上的审批卡片不会出现，也不会拦下任何操作。只有电脑端为这台手机打开了「终端」权限才能使用，默认是不给的。';

  @override
  String get terminalOpen => '我明白，打开终端';

  @override
  String get terminalClose => '关闭终端';

  @override
  String get terminalOpening => '正在打开终端…';

  @override
  String terminalExitCode(int code) {
    return '已结束 · 退出码 $code';
  }

  @override
  String terminalExitSignal(int signal) {
    return '已结束 · 被信号 $signal 终止';
  }

  @override
  String get terminalEnded => '已结束';

  @override
  String get terminalNotAllowed => '这台手机没有终端权限。';

  @override
  String get historyTitle => '历史';

  @override
  String get historySubtitle => '存在服务器上的密文，只有这台手机能解开';

  @override
  String get historySearch => '在已打开的记录中搜索';

  @override
  String historyEpoch(int epoch) {
    return '第 $epoch 代密钥';
  }

  @override
  String historyTurns(int count) {
    return '$count 个回合';
  }

  @override
  String get historyEmpty => '服务器上没有历史';

  @override
  String historyNoKey(int epoch) {
    return '这台手机没有第 $epoch 代历史密钥，等电脑端重新上传后再看。';
  }

  @override
  String historyDownload(String error) {
    return '无法下载：$error';
  }

  @override
  String get historyEncoding => '存储的数据格式无效。';

  @override
  String get historyDecrypt => '解密失败：这段历史可能属于别的会话或密钥代。';

  @override
  String get historyContent => '已解密，但内容不是会话。';

  @override
  String get historyNotOpened => '点按下载并解密';

  @override
  String get historyNoHost => '请先连接一台电脑。';

  @override
  String get settingsTitle => '设置';

  @override
  String get account => '账号';

  @override
  String get signOut => '退出登录';

  @override
  String get signOutTitle => '退出登录？';

  @override
  String get signOutBody => '配对记录会留在这台手机上，再次登录后恢复。';

  @override
  String get accountSignedIn => '已登录';

  @override
  String get accountUserId => '用户 ID';

  @override
  String get accountLoading => '正在读取账号…';

  @override
  String get accountLoadFailed => '无法读取账号信息';

  @override
  String get accountGroupsLoadFailed => '无法读取分组';

  @override
  String get accountOffline => '连不上服务器';

  @override
  String get accountOfflineBody => '请检查这台手机的网络连接，然后重试。';

  @override
  String get accountQuota => '余额与用量';

  @override
  String get accountQuotaHint => '以美元（USD）计';

  @override
  String get accountBalance => '余额';

  @override
  String get accountUsed => '已用额度';

  @override
  String get accountGroups => '分组';

  @override
  String get accountGroupsHint => '每次调用按模型价格乘以分组倍率计费。你的 Key 可以使用这里的任一分组。';

  @override
  String get accountGroupYours => '你的分组';

  @override
  String accountGroupRatio(String ratio) {
    return '倍率 $ratio';
  }

  @override
  String get groupRatioAuto => '自动';

  @override
  String get security => '安全';

  @override
  String get keyProtected => '这台手机的私钥由系统密钥库保管，无法导出。';

  @override
  String get biometricLock => '打开应用时要求解锁';

  @override
  String get biometricLockHint => '只是便利锁，密钥本身不依赖它。';

  @override
  String get appearance => '外观';

  @override
  String get designStyle => '设计风格';

  @override
  String get styleM3 => 'Material 3';

  @override
  String get styleM3E => 'Material 3 Expressive';

  @override
  String get styleM3Hint => '沉稳、紧凑、熟悉';

  @override
  String get styleM3EHint => '更大胆的形状、弹性动效、强调字体';

  @override
  String get themeMode => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get dynamicColor => '壁纸取色';

  @override
  String get dynamicColorHint => '使用壁纸的颜色（Android 12 及以上）';

  @override
  String get seedColor => '主题色';

  @override
  String seedColorOption(int number) {
    return '颜色 $number';
  }

  @override
  String get colorVariant => '配色';

  @override
  String get variantTonalSpot => '柔和';

  @override
  String get variantVibrant => '鲜明';

  @override
  String get variantExpressive => '表现';

  @override
  String get variantFidelity => '保真';

  @override
  String get variantNeutral => '中性';

  @override
  String get contrast => '对比度';

  @override
  String get contrastStandard => '标准';

  @override
  String get contrastMedium => '中';

  @override
  String get contrastHigh => '高';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String devicesOnHost(String host) {
    return '「$host」上的设备';
  }

  @override
  String get devicesConnectFirst => '连接一台电脑后，才能管理它的设备。';

  @override
  String get effectiveScopes => '这台手机实际有效的权限（服务器授予与电脑本地上限的交集）：';

  @override
  String get terminalScopeNote => '终端权限默认不授予：终端里的 CLI 会自己回答权限提示。';

  @override
  String get settingsScopeNote =>
      '模型与账号权限默认不授予，只能在电脑上打开：它能把代理指向任意服务器、改附加环境变量，风险等同终端。';

  @override
  String get settingsScopeWarning =>
      '这台手机可以改模型与账号：能把代理指向任意服务器、改附加环境变量，足以让电脑运行任意程序，风险等同终端。';

  @override
  String get settingsScopeLocked => '风险等同终端：足以让电脑运行任意程序。只能在电脑上打开，这里只能关闭。';

  @override
  String get thisDevice => '这台手机';

  @override
  String get permissions => '权限';

  @override
  String get serverScopesNote =>
      '这里改的是服务器上的授权。实际生效的是它与电脑为这台设备设的上限的交集：电脑上没放开的权限，在这里勾上也不会生效。';

  @override
  String get savePermissions => '保存权限';

  @override
  String get noScopes => '没有权限';

  @override
  String get revoke => '撤销';

  @override
  String revokeTitle(String name) {
    return '撤销「$name」？';
  }

  @override
  String get revokeBody => '撤销后它就连不上了，需要重新扫码配对。';

  @override
  String lastSeen(String ago) {
    return '$ago在线';
  }

  @override
  String get deviceStatusPending => '待激活';

  @override
  String get deviceStatusActive => '已激活';

  @override
  String get deviceStatusRevoked => '已撤销';

  @override
  String get about => '关于';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get componentGallery => '组件画廊';

  @override
  String get reloginNote => '注销或更换账号后，需要在电脑端重新生成配对二维码。';

  @override
  String get scopeSessions => '查看会话';

  @override
  String get scopePrompt => '发送消息';

  @override
  String get scopeApprove => '审批权限请求';

  @override
  String get scopeFiles => '查看文件';

  @override
  String get scopeFilesWrite => '修改文件';

  @override
  String get scopeGit => '查看 Git';

  @override
  String get scopeGitWrite => 'Git 写操作';

  @override
  String get scopeTerminal => '终端';

  @override
  String get scopeSettings => '模型与账号';

  @override
  String get lockedTitle => 'SkidSense 已锁定';

  @override
  String get unlock => '解锁';

  @override
  String get unlockReason => '解锁 SkidSense';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get noticeSessionExpired => '登录已过期，请重新登录。';

  @override
  String get noticeStoreReset =>
      '这台设备上的登录信息无法读取（是从别的手机迁移过来的吗？）。已为你退出登录，请重新登录并重新配对。';

  @override
  String noticeForgetUnrevoked(String error) {
    return '已在这台手机上忘记，但服务器上的撤销没有成功（$error）。请到电脑上撤销这台手机。';
  }

  @override
  String noticeUndecodable(String method) {
    return '无法解析电脑对 $method 的回答。电脑端的 SkidSense 是最新版吗？';
  }

  @override
  String get errOffline => '未连接到电脑';

  @override
  String get errTimeout => '电脑没有及时回应';

  @override
  String errTimeoutRoute(String route) {
    return '$route：连接超时';
  }

  @override
  String errUnreachableRoute(String route) {
    return '$route：无法连接';
  }

  @override
  String errRouteReason(String route, String reason) {
    return '$route：$reason';
  }

  @override
  String get errUnreachable => '无法连接';

  @override
  String get errNoRoute => '没有可用的连接方式';

  @override
  String get errClosed => '连接已关闭';

  @override
  String get errPeerClosed => '对方关闭了连接';

  @override
  String get errIdle => '连接无响应';

  @override
  String get errHandshakeTimeout => '握手超时';

  @override
  String get errRelayFrameOnLan => '局域网上有东西冒充了中继';

  @override
  String get errPlaintextAfterHandshake => '握手确认后收到了伪造的消息';

  @override
  String errProtocol(String code) {
    return '连接校验失败（$code）';
  }

  @override
  String get errBadResponse => '电脑的回答格式有误';

  @override
  String get errTooLarge => '内容过大';

  @override
  String get errHelloRefused => '电脑拒绝了这台手机';

  @override
  String errHelloRefusedReason(String reason) {
    return '电脑拒绝了这台手机：$reason';
  }

  @override
  String get errBye => '电脑断开了连接';

  @override
  String errByeReason(String reason) {
    return '电脑断开了连接：$reason';
  }

  @override
  String get errRevoked => '这台手机已被撤销，需要重新扫码配对。';

  @override
  String get errHostGone => '服务器上已没有这次配对（电脑或这台手机已被移除），需要重新扫码配对。';

  @override
  String errGrant(String error) {
    return '无法获取授权凭证：$error';
  }

  @override
  String get errCompanionDisabled => '服务器未启用远程控制';

  @override
  String get errNoHost => '还没有选择电脑';

  @override
  String get errUploadDesync => '上传进度与电脑不一致，请重新添加这个附件。';

  @override
  String get errTooManyUploads => '同时上传的附件不能超过 8 个';

  @override
  String get errUploadTooLarge => '单个附件不能超过 20 MiB';

  @override
  String get errUploadsTooLarge => '附件合计不能超过 20 MiB';

  @override
  String get errNoKeystore => '系统密钥库不可用，无法生成设备密钥';

  @override
  String get errKeyUnreadable => '暂时读不了系统密钥库，请稍后再试。';

  @override
  String errUnknown(String detail) {
    return '出了点问题：$detail';
  }

  @override
  String get hsrUnsupportedVersion => '电脑端的协议版本与手机端不一致，请更新';

  @override
  String get hsrWrongHost => '连到的不是配对的那台电脑';

  @override
  String get hsrEnrollClosed => '配对码已失效，请在电脑上重新生成二维码';

  @override
  String get hsrUnknownDevice => '这台手机没有与该电脑配对，或已被撤销';

  @override
  String get hsrHandshakeFailed => '握手失败：配对码不对，或不是你配对的那台电脑';

  @override
  String get hsrReplayed => '握手被判为重放，请重试';

  @override
  String get hsrRateLimited => '尝试太频繁，请稍后再试';

  @override
  String get hsrDisabled => '电脑端关闭了远程控制';

  @override
  String get relayHostOffline => '电脑不在线';

  @override
  String get relayUnauthorized => '登录已失效，请重新登录';

  @override
  String get relayRevoked => '这台手机已被撤销，需要重新配对';

  @override
  String get relayRateLimited => '请求太频繁，请稍后再试';

  @override
  String get relayTooLarge => '消息过大';

  @override
  String get relaySuperseded => '这台手机在别处连上了同一台电脑';

  @override
  String get relayShutdown => '中继服务正在重启';

  @override
  String get relayHostClosed => '电脑结束了这个连接';

  @override
  String relayOther(String code) {
    return '中继拒绝了连接（$code）';
  }

  @override
  String hsrOther(String code) {
    return '电脑拒绝了连接（$code）';
  }

  @override
  String get carrierRefused => '被拒绝';

  @override
  String get carrierNoCredentials => '未登录';

  @override
  String get carrierNoRelay => '没有中继地址';

  @override
  String get carrierUpgrade => '不是 SkidSense 的连接端点';

  @override
  String get carrierTls => '安全连接失败';

  @override
  String get carrierForbidden => '服务器拒绝了这台手机';

  @override
  String get carrierNotFound => '服务器上找不到这次配对或中继端点';

  @override
  String get carrierCredentialsUnavailable => '暂时无法确认登录状态';

  @override
  String backendServer(String message) {
    return '$message';
  }

  @override
  String get backendNotSignedIn => '尚未登录';

  @override
  String get backendSessionExpired => '登录已过期，请重新登录。';

  @override
  String backendUnreachable(String base) {
    return '无法连接服务器（$base）';
  }

  @override
  String backendInsecure(String base) {
    return '$base 是未加密的 http://，登录凭据会以明文经过互联网。请使用服务器的 https:// 地址。';
  }

  @override
  String backendHttp(int status) {
    return '服务器返回 HTTP $status';
  }

  @override
  String backendRefreshFailed(int status) {
    return '暂时无法更新登录状态（HTTP $status），请稍后再试';
  }

  @override
  String backendRefreshFailedIn(int status, int seconds) {
    return '暂时无法更新登录状态（HTTP $status），请在 $seconds 秒后再试';
  }

  @override
  String backendUnparsable(String base) {
    return '服务器返回了无法解析的内容（$base 是不是填错了？）';
  }

  @override
  String get backendBadData => '服务器返回的数据格式不对';

  @override
  String get backendNoCredentials => '登录失败：服务器没有返回凭证';

  @override
  String get backendVerificationIncomplete => '登录需要二次验证，但服务器没有给出验证流程';

  @override
  String get backendVerifyFailed => '验证码错误或已过期';

  @override
  String get backendRateLimited => '请求太频繁，请稍后再试';

  @override
  String backendRateLimitedIn(int seconds) {
    return '请求太频繁，请在 $seconds 秒后再试';
  }

  @override
  String get pairErrNotSignedIn => '请先登录';

  @override
  String pairErrWrongBackend(String server, String signedIn) {
    return '这个二维码属于 $server，而你登录的是 $signedIn。两端必须登录同一个服务器。';
  }

  @override
  String get pairErrNoTicket => '服务器没有给出配对凭证，请重新生成二维码';

  @override
  String pairErrNoGrant(String error) {
    return '这台手机在这台电脑上已登记，但拿不到接入凭证（$error）。请在电脑上检查它是否已被撤销；已撤销的话请重新生成二维码。';
  }

  @override
  String pairErrCleanup(String error) {
    return '无法清理这台手机在服务器上的旧记录（$error）';
  }

  @override
  String get pairCodeInvalid => '配对码无效';

  @override
  String get pairCodeAppTooOld => '这个配对码需要更新版本的手机端';

  @override
  String get pairCodeUnsupported => '配对码版本不受支持';

  @override
  String get pairCodeBadKey => '配对码里的电脑公钥无效';

  @override
  String get tabModels => '模型';

  @override
  String get modelsTitle => '模型';

  @override
  String get modelsReadOnlyTitle => '只读';

  @override
  String get modelsReadOnlyBody => '要在这台手机上修改模型与账号，请在电脑的「远程访问」里为它打开「模型与账号」权限。';

  @override
  String get modelsReadOnlyUnsupported => '这台电脑使用的服务器还不支持从手机修改模型与账号，这里只能查看。';

  @override
  String get modelsReadOnlyOldComputer =>
      '这台电脑上的 SkidSense 还不支持从手机修改这些设置：在电脑上更新后即可在这里修改。';

  @override
  String get modelsRoute => '线路';

  @override
  String get modelsRouteHint => '代理的请求走哪条线路。切换会影响这台电脑上的所有对话。';

  @override
  String get modelsLocalMode => '本地';

  @override
  String get modelsLocalModeHint => '使用本机上各代理自己的账号与订阅，不经由第一方服务。';

  @override
  String get modelsCloudMode => '云端';

  @override
  String get modelsCloudModeHint => '所有代理经由你的第一方账号，只用你在 API Key 里分配的模型。';

  @override
  String get modelsSwitch => '切换';

  @override
  String get modelsSwitchCloudTitle => '切换到云端？';

  @override
  String get modelsSwitchCloudBody =>
      '这会影响这台电脑上的所有对话：从下一个回合起，所有代理都经由你的第一方账号，只用分配给它的模型。';

  @override
  String get modelsSwitchLocalTitle => '切换回本地？';

  @override
  String get modelsSwitchLocalBody =>
      '这会影响这台电脑上的所有对话：从下一个回合起，每个代理都用「本地账号」里为它选的账号。';

  @override
  String get modelsSwitchedCloud => '已切到云端';

  @override
  String get modelsSwitchedLocal => '已切回本地';

  @override
  String get modelsSwitchRefused => '电脑没有切换';

  @override
  String get modelsLocal => '本地账号';

  @override
  String get modelsLocalHint => '本地模式下每个代理用哪个账号。只在电脑启动它时注入，不修改 CLI 自己的配置文件。';

  @override
  String get modelsLocalCloudNote => '现在是云端模式，走第一方账号；这里的选择切回本地模式后生效。';

  @override
  String get modelsLoading => '正在读取电脑的模型与账号…';

  @override
  String get modelsNoHarnesses => '这台电脑上没有可以选择账号的代理。';

  @override
  String get modelsNotInstalled => '未安装';

  @override
  String get modelsNotDriven => '暂未接入';

  @override
  String get modelsChoiceCli => '跟随 CLI 自身配置';

  @override
  String get modelsChoiceOfficial => '官方订阅（强制）';

  @override
  String get modelsChoiceGone => '账号已删除';

  @override
  String get modelsRouteCli => '由 CLI 自己的配置决定（例如 cc-switch 写入的配置文件）';

  @override
  String get modelsRouteOfficial =>
      '强制走 Anthropic 官方订阅登录，压过 settings.json 里的第三方端点';

  @override
  String get modelsRouteModelByCli => '由 CLI 决定模型';

  @override
  String get modelsNoKeyStored => '未存 Key';

  @override
  String modelsChoiceTitle(String agent) {
    return '$agent 的账号';
  }

  @override
  String modelsChoiceHint(String dialect) {
    return '可选用 $dialect 协议的账号';
  }

  @override
  String modelsChoiceNone(String dialect) {
    return '还没有 $dialect 协议的账号。';
  }

  @override
  String get modelsAccounts => '账号';

  @override
  String get modelsAccountsHint =>
      '从预设添加 DeepSeek、智谱、Kimi、OpenRouter 等，或填自己的中转站。Key 存在电脑的系统钥匙串里。';

  @override
  String get modelsAccountsHintReadOnly => '电脑上的服务商账号。Key 存在电脑的系统钥匙串里。';

  @override
  String get modelsNoAccounts => '还没有账号。添加一个：选个预设、填 Key 就能用。';

  @override
  String get modelsAddAccount => '添加账号';

  @override
  String get modelsLegacy => '旧版端点';

  @override
  String get modelsLegacyHint => '选择协议后可设为账号';

  @override
  String modelsPresetTag(String preset) {
    return '$preset 预设';
  }

  @override
  String get modelsKeyStored => '已存 Key';

  @override
  String get modelsKeyMissing => '没有 Key';

  @override
  String modelsDialectModels(String dialect, int count) {
    return '$dialect（$count 个模型）';
  }

  @override
  String modelsDeleteAccountTitle(String name) {
    return '删除账号「$name」？';
  }

  @override
  String get modelsDeleteAccountBody =>
      '它的 Key 会一并从钥匙串删除；正在用它的代理会回到「跟随 CLI 自身配置」。';

  @override
  String modelsAccountDeleted(String name) {
    return '已删除「$name」';
  }

  @override
  String get modelsDeleteConflict => '这个账号已在别处修改，已重新读取。确认后如仍要删除，请再操作一次。';

  @override
  String get modelsCloud => '云端 API Key';

  @override
  String get modelsCloudHint =>
      '云端模式靠它们：选一把 Key「分配模型」，把它能用的模型分给各个代理。用这台手机自己的登录管理。';

  @override
  String get keysLoading => '正在读取 Key…';

  @override
  String get keysEmpty => '还没有 Key，新建一个才能用云端模式。';

  @override
  String get keyUnnamed => '未命名';

  @override
  String get assignUnnamedKey => '第一方 Key';

  @override
  String get keyUnlimited => '不限额度';

  @override
  String keyRemaining(String amount) {
    return '剩余 $amount';
  }

  @override
  String keyGroupNamed(String group) {
    return '分组 $group';
  }

  @override
  String get keyGroupDefault => '跟随账号默认';

  @override
  String get keyDisabled => '已禁用';

  @override
  String get keyExpired => '已过期';

  @override
  String get keyExhausted => '额度用完';

  @override
  String get keyAssign => '分配模型';

  @override
  String get keyReveal => '显示完整 Key';

  @override
  String get keyCreate => '新建 Key';

  @override
  String get keyCreateTitle => '新建 API Key';

  @override
  String get keyCreateHint => '用这台手机的登录在你的账号里新建，不经过电脑。';

  @override
  String get keyName => '名称';

  @override
  String get keyNameHint => '例如 我的笔记本';

  @override
  String get keyNameRequired => '给这个 Key 起个名字';

  @override
  String keyNameTooLong(int letters, int chinese) {
    return '名称太长：最多 $letters 个英文字母或 $chinese 个汉字';
  }

  @override
  String get keyGroup => '分组';

  @override
  String get keyGroupsLoading => '正在读取分组…';

  @override
  String get keyUnlimitedHint => '从账号余额扣费，这把 Key 自己不设上限';

  @override
  String get keyQuota => '额度（美元）';

  @override
  String get keyQuotaInvalid => '填一个大于 0 的金额';

  @override
  String get keyExpiry => '有效期';

  @override
  String get keyExpiryNever => '永不过期';

  @override
  String keyExpiryDays(int days) {
    return '$days 天';
  }

  @override
  String get keyCreatedTitle => 'Key 已新建';

  @override
  String get keyShownOnce => '这是完整 Key，只显示这一次。';

  @override
  String keyRevealTitle(String name) {
    return 'Key「$name」';
  }

  @override
  String get keyRevealHint => '妥善保管：拿到它的人就能用你的额度。';

  @override
  String get keyRevealReason => '解锁以显示完整 Key';

  @override
  String keyDeleteTitle(String name) {
    return '删除 Key「$name」？';
  }

  @override
  String get keyDeleteBody => '用它的地方都会失效，包括用它做的云端分配。删除后无法恢复。';

  @override
  String get modelsAssigned => '已分配给代理';

  @override
  String get modelsAssignedHint => '云端模式下各代理走的分配。';

  @override
  String get modelsNoModelsAssigned => '未指定模型';

  @override
  String get modelsUnassign => '取消分配';

  @override
  String modelsUnassignTitle(String name) {
    return '取消分配「$name」？';
  }

  @override
  String get modelsUnassignBody => '云端模式下这个代理就不能再用这些模型；Key 本身保留。';

  @override
  String modelsUnassigned(String name) {
    return '已取消分配「$name」';
  }

  @override
  String get assignTitle => '分配模型';

  @override
  String assignHint(String key) {
    return '勾选模型，并选择分配给哪个代理；云端模式就用这些分配。每项显示为「代理 · $key」。';
  }

  @override
  String get assignTo => '当前分配给';

  @override
  String get assignToHint => '之后勾选的模型会归到这个代理；换一个再勾即可分给多个。';

  @override
  String get assignToOnlyHint => '之后勾选的模型会归到这个代理；这台电脑上只有这一个代理。';

  @override
  String get assignAgentsLoading => '正在读取电脑上的代理…';

  @override
  String get assignAgentsFailed => '无法读取电脑上的代理';

  @override
  String get assignNoAgents => '这台电脑上没有已安装并已接入的代理。';

  @override
  String get assignSearch => '搜索模型';

  @override
  String get assignLoading => '正在获取这把 Key 的模型列表…';

  @override
  String get assignNoModels => '这把 Key 没有返回任何模型。';

  @override
  String assignGoesTo(String agents) {
    return '分配给 $agents';
  }

  @override
  String assignSummary(String agent, int count, int places) {
    return '$agent：已勾选 $count 个模型 · 共 $places 处分配';
  }

  @override
  String get assignConfirm => '确认';

  @override
  String get assignNoneSelected => '至少勾选一个模型';

  @override
  String assignTooMany(int limit) {
    return '每个代理一次最多分配 $limit 个模型';
  }

  @override
  String assignPartial(String made, String error) {
    return '只完成了一部分。已建好：$made。之后失败：$error';
  }

  @override
  String assignDone(int count) {
    return '已为 $count 个代理配好';
  }

  @override
  String get ctxTitle => '上下文与自动压缩';

  @override
  String get ctxEntry => '每个模型的压缩阈值';

  @override
  String get ctxEntryHint => '上下文超过你设的大小才自动压缩';

  @override
  String ctxHint(String min, String max) {
    return '给每个模型设一个大小（$min–$max）：上下文超过它才自动压缩，不到就不压缩。没设的模型照旧由代理自己决定。窗口是模型能装下的上限。';
  }

  @override
  String get ctxLoading => '正在读取模型…';

  @override
  String get ctxEmpty => '还没有可设置的模型。';

  @override
  String ctxCliGroup(String agent) {
    return '$agent 自带';
  }

  @override
  String ctxCloudGroup(String agent, String key) {
    return '$agent · 云端 Key「$key」';
  }

  @override
  String get ctxDefaultModel => '默认模型';

  @override
  String get ctxNoAgents => '还没有能用它的代理。';

  @override
  String ctxSupportLine(String agents, String support) {
    return '$agents：$support';
  }

  @override
  String get ctxSupportNative => '到阈值时自动压缩';

  @override
  String get ctxSupportManaged => '在回合之间判断，超过就先压缩再发消息';

  @override
  String get ctxSupportUnsupported => '不支持设置，由它自己决定';

  @override
  String ctxWindow(String size, String source) {
    return '窗口 $size · $source';
  }

  @override
  String get ctxSourceCustom => '你设的';

  @override
  String get ctxSourceDiscovered => '端点报告';

  @override
  String get ctxSourcePreset => '账号预设';

  @override
  String get ctxSourceKnown => '型号默认';

  @override
  String get ctxSourceEstimate => '估计';

  @override
  String get ctxDefault => '默认';

  @override
  String ctxSliderLabel(String model) {
    return '$model 的压缩阈值';
  }

  @override
  String ctxCustom(String size) {
    return '上下文超过 $size 时自动压缩，没超过不压缩。';
  }

  @override
  String get ctxDefaultState => '默认：由代理自己决定。';

  @override
  String ctxOverWindow(String window) {
    return '比窗口 $window 还大：窗口装满前代理会自己压缩，窗口不对可以改。';
  }

  @override
  String get ctxEditWindow => '改窗口大小';

  @override
  String get ctxResetWindow => '恢复推算的窗口';

  @override
  String get ctxReset => '恢复默认';

  @override
  String get ctxWindowField => '窗口，如 200k、1m 或 200000';

  @override
  String get ctxWindowInvalid => '窗口写成 200k、1m 或 200000 这样的数（1K–100M）';

  @override
  String get editorAddTitle => '添加账号';

  @override
  String get editorEditTitle => '编辑账号';

  @override
  String get editorAdd => '添加';

  @override
  String editorSaved(String name) {
    return '已保存「$name」';
  }

  @override
  String editorAdded(String name) {
    return '已添加「$name」，到「本地账号」为代理选用它';
  }

  @override
  String get editorPreset => '预设';

  @override
  String get editorPresetHint => '选一个预设会填好各协议的地址与模型。模型名经常更新，保存前可用「获取模型」刷新。';

  @override
  String get editorPresetSearch => '搜索供应商';

  @override
  String get editorPresetsLoading => '正在读取预设…';

  @override
  String get editorPresetCredit => '部分预设来自 cc-switch，以 MIT 许可使用。';

  @override
  String get editorPresetLicense => '许可声明';

  @override
  String get editorPresetCustom => '自定义';

  @override
  String get editorAccountSection => '账号';

  @override
  String get editorName => '名称';

  @override
  String get editorNameHint => '例如 DeepSeek（个人）';

  @override
  String get editorNameRequired => '给账号起个名字';

  @override
  String get editorNote => '备注';

  @override
  String get editorNoteHint => '谁的 Key、用途、计费方式…';

  @override
  String get editorApiKey => 'API Key';

  @override
  String get editorKeyShared => '所有协议共用，存进电脑的系统钥匙串，之后不再显示。';

  @override
  String get editorKeyKept => '所有协议共用。已存 Key，留空表示不修改。';

  @override
  String get editorKeyWillClear => '保存时会清除已存的 Key。';

  @override
  String get editorClearKey => '清除已存的 Key';

  @override
  String get editorClearKeyHint => '给不需要 Key 的端点用';

  @override
  String get editorProtocols => '协议端点';

  @override
  String get editorProtocolsHint => '一个供应商一个账号：按它支持的协议分别填端点，共用一把 Key。';

  @override
  String get editorNoProtocol => '至少启用一个协议端点';

  @override
  String editorDialectFor(String agents) {
    return '给 $agents 用';
  }

  @override
  String get editorBaseUrl => 'Base URL';

  @override
  String get editorUrlRequired => '请填写 Base URL';

  @override
  String get editorUrlNotAddress => '不是有效的地址，例如 https://api.example.com/v1';

  @override
  String get editorUrlNotHttp => '必须以 http:// 或 https:// 开头';

  @override
  String get editorModels => '模型';

  @override
  String get editorModelsHint => '「获取模型」直接向端点获取它的模型列表。';

  @override
  String get editorFetch => '获取模型';

  @override
  String get editorModelList => '模型 ID';

  @override
  String get editorModelsHelper => '每行一个，或用逗号分隔';

  @override
  String get editorCodexNeedsModel => 'Codex 用的这个端点至少要有一个模型：填入模型 ID，或设定默认模型';

  @override
  String get editorFetching => '正在向端点获取模型列表…';

  @override
  String get editorFetchFailed => '没能获取模型';

  @override
  String editorFetched(int count) {
    return '获取到 $count 个模型，已填入列表。';
  }

  @override
  String editorFetchedSome(int count, int kept) {
    return '获取到 $count 个模型，已填入前 $kept 个（每个协议最多 $kept 个）。';
  }

  @override
  String get editorFetchNeedsUrl => '先填 Base URL';

  @override
  String get editorFetchNoQuery => '地址里不能有 ? 或 #：模型列表的路径要接在它后面';

  @override
  String editorFetchRejected(int status) {
    return '密钥被拒绝（$status），检查这个端点的 Key';
  }

  @override
  String editorFetchHttp(int status) {
    return '端点回应 HTTP $status';
  }

  @override
  String get editorFetchTimeout => '端点 20 秒内没有回应';

  @override
  String get editorFetchNetwork => '连不上这个地址';

  @override
  String get editorFetchNotJson => '端点的回应不是 JSON';

  @override
  String get editorFetchEmpty => '端点没有列出任何模型';

  @override
  String get editorFetchTooLarge => '端点的回应太大（超过 8 MiB）';

  @override
  String get editorModelMap => '模型对应';

  @override
  String get editorModelMapHint => '代理默认用哪个模型。';

  @override
  String get editorModelMapHintAnthropic => 'Claude Code 的各个槽位用哪个模型；空着的同主模型。';

  @override
  String get editorSlotMain => '主模型';

  @override
  String get editorSlotDefault => '默认模型';

  @override
  String get editorSlotHaiku => 'Haiku（后台）';

  @override
  String get editorSlotSubagent => '子代理';

  @override
  String get editorSameAsMain => '同主模型';

  @override
  String get editorPickModel => '从列表选择';

  @override
  String get editorExtraEnv => '附加环境变量';

  @override
  String get editorExtraEnvHint =>
      '只注入 Claude Code。端点、Key 这类变量由路由本身管理，不能在这里覆盖。';

  @override
  String get editorExtraEnvField => '变量';

  @override
  String get editorExtraEnvFormat => '每行一个 KEY=VALUE';

  @override
  String editorEnvLine(String line) {
    return '不是 KEY=VALUE：$line';
  }

  @override
  String editorEnvBadName(String name) {
    return '「$name」不是合法的环境变量名（大写字母开头，只能有大写字母、数字、下划线）';
  }

  @override
  String editorEnvReserved(String name) {
    return '「$name」由路由本身管理，不能在账号里覆盖';
  }

  @override
  String get editorAdopt => '并入旧版端点';

  @override
  String editorAdopted(String name) {
    return '并入旧版端点「$name」';
  }

  @override
  String get editorAdoptUndo => '不并入';

  @override
  String get editorAdoptHint => '选一个旧版端点和它用的协议：它会成为这个账号在该协议的端点，Key 一起带过来。';

  @override
  String get editorAdoptProtocol => '它用的协议';

  @override
  String get editorAdoptAction => '并入';

  @override
  String get editorLegacyTitle => '旧版端点';

  @override
  String get editorLegacyBody => '它是在账号功能之前建的，没有说明协议。打开它用的协议，保存后就成为账号。';

  @override
  String get editorConflictTitle => '在别处被修改了';

  @override
  String get editorConflictBody => '你编辑时，电脑或另一台设备改了这个账号。重新载入会放弃这里的修改。';

  @override
  String get editorReload => '重新载入';

  @override
  String editorReloadFailed(String error) {
    return '重新读取失败：$error';
  }

  @override
  String get editorDeletedElsewhere => '这个账号已在别处删除。';

  @override
  String get editorKeyRequired => '换了服务器地址，需要重新填 API Key';

  @override
  String get editorKeyRequiredBody =>
      '已存的 Key 不能带去新的地址。重新填 API Key，或清除已存的 Key，再保存。';

  @override
  String editorFixFields(int count) {
    return '有 $count 处需要修改';
  }

  @override
  String get editorStatusConflict => '这个账号在别处被改过：到顶部重新载入';

  @override
  String get editorStatusRefused => '没有保存：原因见顶部';

  @override
  String editorTooLong(int limit) {
    return '最多 $limit 个字符';
  }

  @override
  String editorTooMany(int limit) {
    return '最多 $limit 项';
  }

  @override
  String editorTooManyModels(int limit) {
    return '最多 $limit 个模型';
  }

  @override
  String editorTooManyEnv(int limit) {
    return '最多 $limit 个变量';
  }

  @override
  String get editorEmpty => '不能为空';

  @override
  String get editorKeyInvalid => '只能是可打印的 ASCII 字符，不能有空格';

  @override
  String get editorUrlInvalid => '不能有空白或控制字符';

  @override
  String get editorControlChars => '不能含控制字符';

  @override
  String editorProblemIn(String item, String problem) {
    return '$item：$problem';
  }

  @override
  String get editorDiscardTitle => '放弃修改？';

  @override
  String get editorDiscardBody => '这里的修改还没有保存。';

  @override
  String get editorUnknownProtocol => '这个账号用了这个版本的 App 不认识的协议：请在电脑上编辑，或更新 App。';

  @override
  String editorProtocolTwice(String protocol) {
    return '$protocol 端点重复了';
  }

  @override
  String get errProviderUnsupported => '这台电脑不支持指定账号的模型，请重新选择模型。';

  @override
  String get backendKeyNotLocated => 'Key 已新建，但之后的列表里找不到它。新建另一把之前，先看看现有的 Key。';

  @override
  String get backendNoKey => '服务器没有返回 Key';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class L10nZhHant extends L10nZh {
  L10nZhHant() : super('zh_Hant');

  @override
  String get appName => 'SkidSense';

  @override
  String get ok => '好';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重試';

  @override
  String get back => '返回';

  @override
  String get close => '關閉';

  @override
  String get save => '儲存';

  @override
  String get delete => '刪除';

  @override
  String get rename => '重新命名';

  @override
  String get refresh => '重新整理';

  @override
  String get copy => '複製';

  @override
  String get copied => '已複製';

  @override
  String get done => '完成';

  @override
  String get edit => '編輯';

  @override
  String get preview => '預覽';

  @override
  String get reload => '重新載入';

  @override
  String get more => '更多';

  @override
  String get search => '搜尋';

  @override
  String get clear => '清除';

  @override
  String get create => '建立';

  @override
  String get continueAction => '繼續';

  @override
  String get dismiss => '關閉';

  @override
  String get none => '—';

  @override
  String get loginTitle => '登入';

  @override
  String get loginSubtitle => '使用與電腦端 SkidSense 相同的帳號登入——兩端靠它找到彼此。';

  @override
  String get serverAddress => '伺服器';

  @override
  String serverAddressUsed(String address) {
    return '將使用 $address';
  }

  @override
  String get serverAddressInvalid => '請輸入伺服器位址，例如 https://example.com';

  @override
  String get username => '使用者名稱';

  @override
  String get password => '密碼';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get signIn => '登入';

  @override
  String get testConnection => '測試連線';

  @override
  String serverReachable(String name) {
    return '伺服器可用：$name';
  }

  @override
  String get captchaTitle => '真人驗證';

  @override
  String get captchaPassed => '已通過驗證';

  @override
  String get captchaRedo => '重新驗證';

  @override
  String captchaFailed(String code) {
    return '驗證失敗（$code），請重試。';
  }

  @override
  String get captchaExpired => '驗證已逾時，請重試。';

  @override
  String get captchaOnSignIn => '登入時會跳出真人驗證。';

  @override
  String get captchaLoading => '正在載入真人驗證…';

  @override
  String get captchaLoadFailed => '真人驗證載入失敗';

  @override
  String get captchaLoadFailedHint => '請檢查網路連線，然後再試一次。';

  @override
  String get passwordLoginDisabled => '這個伺服器關閉了密碼登入。';

  @override
  String get pairingAfterLogin => '登入與配對是兩個步驟：先在這裡登入，再掃描電腦上的 QR 碼。';

  @override
  String get twoFactorTitle => '兩步驟驗證';

  @override
  String get twoFactorHint => '輸入驗證器 App 中的 6 位數驗證碼，或一組備用碼。';

  @override
  String get twoFactorRequired => '這個帳號需要第二步驗證。';

  @override
  String twoFactorMethods(String methods) {
    return '可用方式：$methods';
  }

  @override
  String get verificationCode => '驗證碼';

  @override
  String get verify => '驗證';

  @override
  String get twoFactorPasskeyOnly =>
      '這個帳號的第二步驗證是通行金鑰（Passkey），App 目前還不支援。請先到網頁版開啟兩步驟驗證並綁定驗證器 App，再回到這裡用它的驗證碼登入。';

  @override
  String get hostsTitle => '我的電腦';

  @override
  String signedInAs(String user, String server) {
    return '$user · $server';
  }

  @override
  String get pairComputer => '配對電腦';

  @override
  String get pairedSection => '已配對';

  @override
  String get pairedSectionHint => '可以直接連線';

  @override
  String get otherHostsSection => '這個帳號的其他電腦';

  @override
  String get otherHostsHint => '尚未與這支手機配對';

  @override
  String get presenceOnline => '線上';

  @override
  String get presenceRelayOffline => '中繼離線';

  @override
  String get presenceOffline => '離線';

  @override
  String get presenceRelayOfflineHint => '沒有連到中繼——在區域網路中仍可能連得上。';

  @override
  String get fingerprint => '指紋';

  @override
  String get lanAddresses => '區域網路';

  @override
  String get connect => '連線';

  @override
  String get forget => '忘記';

  @override
  String forgetTitle(String name) {
    return '要忘記「$name」嗎？';
  }

  @override
  String get forgetBody =>
      '也會在伺服器上撤銷這支手機：電腦會立即中斷它，也不再為它加密歷史記錄。之後要重新掃描 QR 碼才能再連線。';

  @override
  String get forgetAction => '忘記並撤銷';

  @override
  String get noComputersTitle => '還沒有電腦';

  @override
  String get noComputersBody => '在電腦端 SkidSense 中開啟「遠端控制」並產生配對 QR 碼，再回到這裡掃描。';

  @override
  String get hostNeedsQr => '在它上面產生 QR 碼即可配對';

  @override
  String get loadingHosts => '正在讀取電腦清單…';

  @override
  String get settings => '設定';

  @override
  String get pairingTitle => '配對電腦';

  @override
  String get pairingIntro =>
      '在電腦端 SkidSense 開啟「遠端控制」，掃描視窗中的 QR 碼。QR 碼只能使用一次，10 分鐘內有效。';

  @override
  String get scanQr => '掃描 QR 碼';

  @override
  String get pasteLinkSection => '或貼上配對連結';

  @override
  String get pasteLinkLabel => 'skidsense://pair/1?d=…';

  @override
  String get readLink => '讀取連結';

  @override
  String get confirmComputer => '是這台電腦嗎？';

  @override
  String get machineName => '名稱';

  @override
  String get backend => '伺服器';

  @override
  String get fingerprintCheck =>
      '請與電腦螢幕上顯示的指紋逐組核對。若不一致，表示這個 QR 碼不是來自你正在使用的那台電腦。';

  @override
  String get confirmPair => '配對';

  @override
  String get pairStepRegistering => '正在登記這支手機…';

  @override
  String get pairStepAlreadyRegistered => '這支手機已經登記過，正在重新連線…';

  @override
  String get pairStepHandshaking => '正在與電腦交握…';

  @override
  String get pairStepRepairing => '電腦上沒有這支手機的記錄，正在重新配對…';

  @override
  String get pairStepFinishing => '配對完成，正在讀取這支手機獲得的權限…';

  @override
  String pairStepTrying(String route) {
    return '正在嘗試$route…';
  }

  @override
  String get cameraUnavailable => '相機無法使用。請改為貼上配對連結。';

  @override
  String get scannerPrompt => '將電腦上的 QR 碼放進取景框';

  @override
  String get scannerTorch => '手電筒';

  @override
  String get notAPairingCode => '這不是 SkidSense 的配對 QR 碼。';

  @override
  String get tabSessions => '對話';

  @override
  String get tabFiles => '檔案';

  @override
  String get tabGit => 'Git';

  @override
  String get tabHistory => '歷史記錄';

  @override
  String routeLan(String address) {
    return '區域網路 $address';
  }

  @override
  String get routeRelay => '中繼';

  @override
  String statusConnected(String route) {
    return '已連線 · $route';
  }

  @override
  String statusConnectedLimited(String route, int rate) {
    return '已連線 · $route（限速 $rate KB/s）';
  }

  @override
  String statusConnecting(String route) {
    return '正在連線 · $route';
  }

  @override
  String get statusAuthorizing => '正在連線 · 取得授權';

  @override
  String statusWaiting(String error, int seconds) {
    return '$error · $seconds 秒後重試';
  }

  @override
  String statusFailed(String error) {
    return '連線失敗：$error';
  }

  @override
  String get statusIdle => '未連線';

  @override
  String get offlineTitle => '尚未連上電腦';

  @override
  String get offlineBody =>
      '請確認電腦上的 SkidSense 正在執行，且這支手機已與它配對。區域網路無法使用時會自動改走中繼。';

  @override
  String get backToComputers => '電腦';

  @override
  String get searchSessions => '搜尋對話';

  @override
  String get noSessionsTitle => '還沒有對話';

  @override
  String get noSessionsBody => '在電腦上開始一個，或在這裡建立。';

  @override
  String get noSessionsNoPrompt => '這支手機不能建立對話。';

  @override
  String noSearchResults(String query) {
    return '沒有符合「$query」的對話';
  }

  @override
  String get newSession => '新對話';

  @override
  String get workspace => '工作區';

  @override
  String get agent => '代理';

  @override
  String get titleOptional => '標題（可留空）';

  @override
  String get renameSession => '重新命名對話';

  @override
  String get sessionTitle => '標題';

  @override
  String deleteSessionTitle(String title) {
    return '要刪除「$title」嗎？';
  }

  @override
  String get deleteSessionBody => '對話和它的記錄會在電腦上刪除。';

  @override
  String backgroundJobs(int count) {
    return '$count 個背景工作';
  }

  @override
  String get loadingSessions => '正在讀取對話…';

  @override
  String get runStateRunning => '執行中';

  @override
  String get runStateAwaiting => '等你回應';

  @override
  String get runStateStarting => '啟動中';

  @override
  String get runStateIdle => '閒置';

  @override
  String get runStateDone => '已完成';

  @override
  String get runStateError => '失敗';

  @override
  String get runStateAborted => '已停止';

  @override
  String get runStatePending => '等待中';

  @override
  String get runStateCancelled => '已取消';

  @override
  String updatedAgo(String ago) {
    return '$ago更新';
  }

  @override
  String get openingSession => '正在開啟對話…';

  @override
  String get sessionNotFound => '電腦上沒有這個對話。';

  @override
  String get openTerminal => '終端機';

  @override
  String get openFiles => '檔案';

  @override
  String get openGit => 'Git';

  @override
  String get approvalPermission => '需要你的許可';

  @override
  String get approvalQuestion => '代理在提問';

  @override
  String get approvalInput => '代理在等待輸入';

  @override
  String get approvalOther => '代理需要回應';

  @override
  String get approvalFreeText => '可自由作答';

  @override
  String approvalCwd(String cwd) {
    return '工作目錄：$cwd';
  }

  @override
  String approvalScopes(String scopes) {
    return '要求的權限：$scopes';
  }

  @override
  String get approvalNoPermission => '這支手機沒有核准權限。請在電腦上回應，或改用有權限的裝置。';

  @override
  String approvalAnsweredElsewhere(String device) {
    return '已在「$device」上回應';
  }

  @override
  String get allow => '允許';

  @override
  String get deny => '拒絕';

  @override
  String get sendAnswer => '送出回答';

  @override
  String get skip => '略過';

  @override
  String get cancelTurn => '取消這一輪';

  @override
  String get answerPlaceholder => '你的回答';

  @override
  String get toolInput => '輸入';

  @override
  String get toolResult => '結果';

  @override
  String toolTruncated(String label, String size) {
    return '$label已截斷（原始 $size）';
  }

  @override
  String get messageHint => '說點什麼';

  @override
  String get steerHint => '追加到進行中的這一輪';

  @override
  String get send => '傳送';

  @override
  String get steer => '插話';

  @override
  String get stop => '停止';

  @override
  String get composerOptions => '選項';

  @override
  String get attach => '附加檔案';

  @override
  String get attachmentsNote => '附件會隨下一則訊息傳送；離開這個對話就會捨棄。';

  @override
  String get remove => '移除';

  @override
  String get noPromptPermission => '這支手機沒有傳送訊息的權限。';

  @override
  String get options => '傳送選項';

  @override
  String get model => '模型';

  @override
  String get modelDefault => '預設';

  @override
  String get noModels => '沒有可選的模型清單';

  @override
  String modelDefaultNamed(String model) {
    return '預設（$model）';
  }

  @override
  String get composerModelsLoading => '正在讀取模型…';

  @override
  String get composerRouteCloud => '雲端：經由你的第一方帳號';

  @override
  String composerRouteAccount(String account) {
    return '本機帳號：$account';
  }

  @override
  String get composerRouteOfficial => '本機：Anthropic 官方訂閱（強制）';

  @override
  String get composerRouteCli => '本機：使用代理自己的設定';

  @override
  String get composerAccount => '帳號';

  @override
  String composerAccountHint(String agent) {
    return '在電腦上設定：$agent 的所有對話從下一個回合起都使用它。';
  }

  @override
  String get composerModelsCloud => '雲端模型';

  @override
  String composerModelsAccount(String account) {
    return '$account 的模型';
  }

  @override
  String get composerModelsCli => 'CLI 本身的模型';

  @override
  String get composerModelsOtherAccounts => '其他帳號（僅本次對話）';

  @override
  String get composerModelsOtherEndpoints => '其他端點（僅本次對話）';

  @override
  String get composerModelsOtherHint => '只有這個對話使用它，電腦上設定的帳號不變。';

  @override
  String get composerCloudEmptyTitle => '雲端還沒有模型';

  @override
  String get composerCloudEmptyBody => '雲端模式只提供從雲端 Key 分配給這個代理的模型。';

  @override
  String get composerOpenModels => '到「模型」分配';

  @override
  String get slashTitle => '指令';

  @override
  String slashCount(int count) {
    return '$count 個指令';
  }

  @override
  String get slashLoading => '正在讀取指令…';

  @override
  String get slashSourceBuiltin => '內建';

  @override
  String get slashSourceCommand => '指令';

  @override
  String get slashSourceSkill => '技能';

  @override
  String get slashScopeWorkspace => '本工作區';

  @override
  String get slashScopeGlobal => '全域';

  @override
  String slashAliases(String names) {
    return '別名 $names';
  }

  @override
  String get effort => '思考強度';

  @override
  String get effortMinimal => '最低';

  @override
  String get effortLow => '低';

  @override
  String get effortMedium => '中';

  @override
  String get effortHigh => '高';

  @override
  String get effortXhigh => '很高';

  @override
  String get effortMax => '最高';

  @override
  String get effortUltra => '極致';

  @override
  String get approvalMode => '核准方式';

  @override
  String get approvalModeLocked => '核准方式（這支手機沒有核准權限，只能使用預設）';

  @override
  String get approvalDefault => '每次詢問';

  @override
  String get approvalAcceptEdits => '自動接受編輯';

  @override
  String get approvalPlan => '僅規劃';

  @override
  String get approvalDontAsk => '不再詢問';

  @override
  String get approvalBypass => '略過所有權限';

  @override
  String get thinking => '思考過程';

  @override
  String get plan => '計畫';

  @override
  String get backgroundTasks => '背景工作';

  @override
  String usageContext(String tokens) {
    return '上下文 $tokens';
  }

  @override
  String usageOutput(String tokens) {
    return '輸出 $tokens';
  }

  @override
  String steered(String text) {
    return '插話：$text';
  }

  @override
  String get compactedAuto => '上下文已自動壓縮';

  @override
  String get compactedManual => '上下文已壓縮';

  @override
  String get subAgent => '子代理';

  @override
  String get subAgentTask => '任務';

  @override
  String get subAgentLatest => '最新發言';

  @override
  String get subAgentReport => '結果';

  @override
  String get workflow => '工作流程';

  @override
  String toolCalls(int count) {
    return '$count 次工具呼叫';
  }

  @override
  String promptRefused(String reason) {
    return '電腦沒有接受這則訊息：$reason';
  }

  @override
  String get promptRefusedPlain => '電腦沒有接受這則訊息。';

  @override
  String get promptUncertain => '沒有收到回應——這一輪可能已經開始。請先查看對話記錄，再決定是否重新傳送。';

  @override
  String get promptUncertainDropped =>
      '沒有收到回應——這一輪可能已經開始。請先查看對話記錄，再決定是否重新傳送；附件已移除，需要重新加入。';

  @override
  String uploadIncomplete(String name) {
    return '「$name」尚未上傳完成。';
  }

  @override
  String uploading(String name) {
    return '正在上傳 $name';
  }

  @override
  String get jumpToLatest => '最新';

  @override
  String get you => '你';

  @override
  String get filesTitle => '檔案';

  @override
  String get searchContent => '搜尋檔案內容';

  @override
  String get regex => '正規表示式';

  @override
  String get searching => '正在搜尋…';

  @override
  String searchSummary(int matches, int files) {
    return '$files 個檔案中 $matches 處符合';
  }

  @override
  String get searchCancelled => '已停止搜尋';

  @override
  String get searchInterrupted => '連線中斷，搜尋已停止，請重新搜尋。';

  @override
  String moreMatches(int count) {
    return '還有 $count 處';
  }

  @override
  String get dirTruncated => '這個資料夾的項目太多，只顯示一部分。';

  @override
  String get emptyDir => '這裡是空的';

  @override
  String get showIgnored => '顯示被忽略的檔案';

  @override
  String get binaryFile => '這是二進位檔案，只能預覽。';

  @override
  String get tooLargeFile => '檔案太大，無法在這裡開啟。';

  @override
  String fileLines(int count, String size) {
    return '$count 行 · $size';
  }

  @override
  String get saved => '已儲存';

  @override
  String get saveConflict => '檔案已在別處被修改，為避免覆寫，已拒絕儲存。請重新載入後再修改。';

  @override
  String get unsavedChanges => '要捨棄你的修改嗎？';

  @override
  String get discard => '捨棄';

  @override
  String get newFile => '新增檔案';

  @override
  String get newFolder => '新增資料夾';

  @override
  String get name => '名稱';

  @override
  String deleteItemTitle(String name) {
    return '要刪除「$name」嗎？';
  }

  @override
  String get deleteItemBody => '它會在電腦上被刪除。';

  @override
  String get noWorkspace => '沒有工作區';

  @override
  String get chooseWorkspace => '工作區';

  @override
  String get root => '根目錄';

  @override
  String get gitTitle => 'Git';

  @override
  String get notARepo => '這個工作區還不是 Git 儲存庫。';

  @override
  String get initRepo => '在這裡初始化儲存庫';

  @override
  String get branch => '分支';

  @override
  String detached(String sha) {
    return '分離於 $sha';
  }

  @override
  String upstream(String name) {
    return '上游 $name';
  }

  @override
  String aheadBehind(int ahead, int behind) {
    return '↑$ahead ↓$behind';
  }

  @override
  String get branches => '分支';

  @override
  String get fetch => '擷取';

  @override
  String get pull => '提取';

  @override
  String get push => '推送';

  @override
  String get switchBranch => '切換';

  @override
  String get currentBranch => '目前';

  @override
  String get remoteBranch => '遠端';

  @override
  String get changes => '變更';

  @override
  String get staged => '已暫存';

  @override
  String get unstaged => '未暫存';

  @override
  String get noChanges => '沒有可提交的變更';

  @override
  String get stage => '暫存';

  @override
  String get unstage => '取消暫存';

  @override
  String get stageAll => '全部暫存';

  @override
  String get discardChanges => '捨棄變更';

  @override
  String discardTitle(String path) {
    return '要捨棄對 $path 的變更嗎？';
  }

  @override
  String get discardBody => '這些變更會在電腦上遺失。';

  @override
  String get commit => '提交';

  @override
  String get commitMessage => '提交說明';

  @override
  String get commitStaged => '提交已暫存的變更';

  @override
  String get committed => '已提交';

  @override
  String renamedFrom(String path) {
    return '來自 $path';
  }

  @override
  String get diffTruncated => '差異太大，只顯示一部分。';

  @override
  String get binaryDiff => '二進位檔案';

  @override
  String get gitModified => '已修改';

  @override
  String get gitAdded => '新增';

  @override
  String get gitDeleted => '已刪除';

  @override
  String get gitRenamed => '已重新命名';

  @override
  String get gitUntracked => '未追蹤';

  @override
  String get gitConflicted => '衝突';

  @override
  String get gitIgnored => '已忽略';

  @override
  String gitOperationFailed(String message) {
    return 'Git：$message';
  }

  @override
  String conflictsBanner(int count) {
    return '$count 個檔案有衝突';
  }

  @override
  String get terminalTitle => '終端機';

  @override
  String get terminalWarningTitle => '終端機會略過核准';

  @override
  String get terminalWarningBody =>
      '終端機中執行的是電腦上真正的 CLI。權限提示由它自己在終端機中回應，手機上不會出現核准卡片，也不會攔下任何操作。只有在電腦端為這支手機開啟「終端機」權限時才能使用，預設是關閉的。';

  @override
  String get terminalOpen => '我了解，開啟終端機';

  @override
  String get terminalClose => '關閉終端機';

  @override
  String get terminalOpening => '正在開啟終端機…';

  @override
  String terminalExitCode(int code) {
    return '已結束 · 結束代碼 $code';
  }

  @override
  String terminalExitSignal(int signal) {
    return '已結束 · 被訊號 $signal 終止';
  }

  @override
  String get terminalEnded => '已結束';

  @override
  String get terminalNotAllowed => '這支手機沒有終端機權限。';

  @override
  String get historyTitle => '歷史記錄';

  @override
  String get historySubtitle => '以密文存放在伺服器上，只有這支手機能解開';

  @override
  String get historySearch => '在已開啟的記錄中搜尋';

  @override
  String historyEpoch(int epoch) {
    return '第 $epoch 代金鑰';
  }

  @override
  String historyTurns(int count) {
    return '$count 輪';
  }

  @override
  String get historyEmpty => '伺服器上沒有歷史記錄';

  @override
  String historyNoKey(int epoch) {
    return '這支手機沒有第 $epoch 代歷史金鑰，等電腦端重新上傳後再查看。';
  }

  @override
  String historyDownload(String error) {
    return '無法下載：$error';
  }

  @override
  String get historyEncoding => '儲存的資料格式無效。';

  @override
  String get historyDecrypt => '解密失敗：這段記錄可能屬於其他對話或金鑰代。';

  @override
  String get historyContent => '已解密，但內容不是對話。';

  @override
  String get historyNotOpened => '點一下以下載並解密';

  @override
  String get historyNoHost => '請先連線一台電腦。';

  @override
  String get settingsTitle => '設定';

  @override
  String get account => '帳號';

  @override
  String get signOut => '登出';

  @override
  String get signOutTitle => '要登出嗎？';

  @override
  String get signOutBody => '配對記錄會保留在這支手機上，再次登入後恢復。';

  @override
  String get accountSignedIn => '已登入';

  @override
  String get accountUserId => '使用者 ID';

  @override
  String get accountLoading => '正在讀取帳號…';

  @override
  String get accountLoadFailed => '無法讀取帳號資訊';

  @override
  String get accountGroupsLoadFailed => '無法讀取群組';

  @override
  String get accountOffline => '無法連線到伺服器';

  @override
  String get accountOfflineBody => '請檢查這支手機的網路連線，然後再試一次。';

  @override
  String get accountQuota => '餘額與用量';

  @override
  String get accountQuotaHint => '以美元（USD）計算';

  @override
  String get accountBalance => '餘額';

  @override
  String get accountUsed => '已用額度';

  @override
  String get accountGroups => '群組';

  @override
  String get accountGroupsHint => '每次呼叫依模型價格乘以群組倍率計費。你的 Key 可以使用這裡的任一群組。';

  @override
  String get accountGroupYours => '你的群組';

  @override
  String accountGroupRatio(String ratio) {
    return '倍率 $ratio';
  }

  @override
  String get groupRatioAuto => '自動';

  @override
  String get security => '安全性';

  @override
  String get keyProtected => '這支手機的私密金鑰由系統金鑰庫保管，無法匯出。';

  @override
  String get biometricLock => '開啟 App 時要求解鎖';

  @override
  String get biometricLockHint => '只是便利用的鎖，金鑰本身不依賴它。';

  @override
  String get appearance => '外觀';

  @override
  String get designStyle => '設計風格';

  @override
  String get styleM3 => 'Material 3';

  @override
  String get styleM3E => 'Material 3 Expressive';

  @override
  String get styleM3Hint => '沉穩、緊湊、熟悉';

  @override
  String get styleM3EHint => '更大膽的形狀、彈性動態、強調字體';

  @override
  String get themeMode => '主題';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get dynamicColor => '桌布配色';

  @override
  String get dynamicColorHint => '使用桌布的顏色（Android 12 以上）';

  @override
  String get seedColor => '主題色';

  @override
  String seedColorOption(int number) {
    return '顏色 $number';
  }

  @override
  String get colorVariant => '配色';

  @override
  String get variantTonalSpot => '柔和';

  @override
  String get variantVibrant => '鮮明';

  @override
  String get variantExpressive => '表現';

  @override
  String get variantFidelity => '保真';

  @override
  String get variantNeutral => '中性';

  @override
  String get contrast => '對比';

  @override
  String get contrastStandard => '標準';

  @override
  String get contrastMedium => '中';

  @override
  String get contrastHigh => '高';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String devicesOnHost(String host) {
    return '「$host」上的裝置';
  }

  @override
  String get devicesConnectFirst => '連線一台電腦後，才能管理它的裝置。';

  @override
  String get effectiveScopes => '這支手機實際生效的權限（伺服器授予與電腦本機上限的交集）：';

  @override
  String get terminalScopeNote => '終端機權限預設不授予：終端機中的 CLI 會自己回應權限提示。';

  @override
  String get settingsScopeNote =>
      '模型與帳號權限預設不授予，只能在電腦上開啟：它能把代理指向任意伺服器、修改額外環境變數，風險等同終端機。';

  @override
  String get settingsScopeWarning =>
      '這支手機可以修改模型與帳號：能把代理指向任意伺服器、修改額外環境變數，足以讓電腦執行任意程式，風險等同終端機。';

  @override
  String get settingsScopeLocked => '風險等同終端機：足以讓電腦執行任意程式。只能在電腦上開啟，這裡只能關閉。';

  @override
  String get thisDevice => '這支手機';

  @override
  String get permissions => '權限';

  @override
  String get serverScopesNote =>
      '這裡修改的是伺服器上的授權。實際生效的是它與電腦為這台裝置設定的上限的交集：電腦上沒有開放的權限，在這裡勾選也不會生效。';

  @override
  String get savePermissions => '儲存權限';

  @override
  String get noScopes => '沒有權限';

  @override
  String get revoke => '撤銷';

  @override
  String revokeTitle(String name) {
    return '要撤銷「$name」嗎？';
  }

  @override
  String get revokeBody => '撤銷後它就無法連線，需要重新掃描 QR 碼配對。';

  @override
  String lastSeen(String ago) {
    return '$ago上線';
  }

  @override
  String get deviceStatusPending => '待啟用';

  @override
  String get deviceStatusActive => '已啟用';

  @override
  String get deviceStatusRevoked => '已撤銷';

  @override
  String get about => '關於';

  @override
  String version(String version) {
    return '版本 $version';
  }

  @override
  String get componentGallery => '元件展示';

  @override
  String get reloginNote => '登出或更換帳號後，需要在電腦端重新產生配對 QR 碼。';

  @override
  String get scopeSessions => '檢視對話';

  @override
  String get scopePrompt => '傳送訊息';

  @override
  String get scopeApprove => '核准權限要求';

  @override
  String get scopeFiles => '檢視檔案';

  @override
  String get scopeFilesWrite => '修改檔案';

  @override
  String get scopeGit => '檢視 Git';

  @override
  String get scopeGitWrite => 'Git 寫入操作';

  @override
  String get scopeTerminal => '終端機';

  @override
  String get scopeSettings => '模型與帳號';

  @override
  String get lockedTitle => 'SkidSense 已鎖定';

  @override
  String get unlock => '解鎖';

  @override
  String get unlockReason => '解鎖 SkidSense';

  @override
  String get justNow => '剛剛';

  @override
  String minutesAgo(int count) {
    return '$count 分鐘前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小時前';
  }

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get noticeSessionExpired => '登入已逾時，請重新登入。';

  @override
  String get noticeStoreReset =>
      '無法讀取這台裝置上的登入資料（是從其他手機移轉過來的嗎？）。已為你登出，請重新登入並重新配對。';

  @override
  String noticeForgetUnrevoked(String error) {
    return '已在這支手機上忘記，但伺服器上的撤銷沒有成功（$error）。請到電腦上撤銷這支手機。';
  }

  @override
  String noticeUndecodable(String method) {
    return '無法解析電腦對 $method 的回應。電腦端的 SkidSense 是最新版嗎？';
  }

  @override
  String get errOffline => '未連線到電腦';

  @override
  String get errTimeout => '電腦沒有及時回應';

  @override
  String errTimeoutRoute(String route) {
    return '$route：連線逾時';
  }

  @override
  String errUnreachableRoute(String route) {
    return '$route：無法連線';
  }

  @override
  String errRouteReason(String route, String reason) {
    return '$route：$reason';
  }

  @override
  String get errUnreachable => '無法連線';

  @override
  String get errNoRoute => '沒有可用的連線方式';

  @override
  String get errClosed => '連線已關閉';

  @override
  String get errPeerClosed => '對方關閉了連線';

  @override
  String get errIdle => '連線沒有回應';

  @override
  String get errHandshakeTimeout => '交握逾時';

  @override
  String get errRelayFrameOnLan => '區域網路上有東西冒充了中繼';

  @override
  String get errPlaintextAfterHandshake => '交握確認後收到偽造的訊息';

  @override
  String errProtocol(String code) {
    return '連線驗證失敗（$code）';
  }

  @override
  String get errBadResponse => '電腦的回應格式有誤';

  @override
  String get errTooLarge => '內容過大';

  @override
  String get errHelloRefused => '電腦拒絕了這支手機';

  @override
  String errHelloRefusedReason(String reason) {
    return '電腦拒絕了這支手機：$reason';
  }

  @override
  String get errBye => '電腦中斷了連線';

  @override
  String errByeReason(String reason) {
    return '電腦中斷了連線：$reason';
  }

  @override
  String get errRevoked => '這支手機已被撤銷，需要重新掃描 QR 碼配對。';

  @override
  String get errHostGone => '伺服器上已沒有這次配對（電腦或這支手機已被移除），需要重新掃描 QR 碼配對。';

  @override
  String errGrant(String error) {
    return '無法取得授權憑證：$error';
  }

  @override
  String get errCompanionDisabled => '伺服器未啟用遠端控制';

  @override
  String get errNoHost => '尚未選擇電腦';

  @override
  String get errUploadDesync => '上傳進度與電腦不一致，請重新加入這個附件。';

  @override
  String get errTooManyUploads => '同時上傳的附件不能超過 8 個';

  @override
  String get errUploadTooLarge => '單一附件不能超過 20 MiB';

  @override
  String get errUploadsTooLarge => '附件合計不能超過 20 MiB';

  @override
  String get errNoKeystore => '系統金鑰庫無法使用，無法產生裝置金鑰';

  @override
  String get errKeyUnreadable => '暫時無法讀取系統金鑰庫，請稍後再試。';

  @override
  String errUnknown(String detail) {
    return '發生問題：$detail';
  }

  @override
  String get hsrUnsupportedVersion => '電腦端的協定版本與手機端不一致，請更新';

  @override
  String get hsrWrongHost => '連到的不是配對的那台電腦';

  @override
  String get hsrEnrollClosed => '配對碼已失效，請在電腦上重新產生 QR 碼';

  @override
  String get hsrUnknownDevice => '這支手機沒有與該電腦配對，或已被撤銷';

  @override
  String get hsrHandshakeFailed => '交握失敗：配對碼錯誤，或不是你配對的那台電腦';

  @override
  String get hsrReplayed => '交握被判定為重放，請重試';

  @override
  String get hsrRateLimited => '嘗試過於頻繁，請稍後再試';

  @override
  String get hsrDisabled => '電腦端關閉了遠端控制';

  @override
  String get relayHostOffline => '電腦不在線上';

  @override
  String get relayUnauthorized => '登入已失效，請重新登入';

  @override
  String get relayRevoked => '這支手機已被撤銷，需要重新配對';

  @override
  String get relayRateLimited => '請求過於頻繁，請稍後再試';

  @override
  String get relayTooLarge => '訊息過大';

  @override
  String get relaySuperseded => '這支手機在別處連上了同一台電腦';

  @override
  String get relayShutdown => '中繼服務正在重新啟動';

  @override
  String get relayHostClosed => '電腦結束了這個連線';

  @override
  String relayOther(String code) {
    return '中繼拒絕了連線（$code）';
  }

  @override
  String hsrOther(String code) {
    return '電腦拒絕了連線（$code）';
  }

  @override
  String get carrierRefused => '被拒絕';

  @override
  String get carrierNoCredentials => '尚未登入';

  @override
  String get carrierNoRelay => '沒有中繼位址';

  @override
  String get carrierUpgrade => '不是 SkidSense 的連線端點';

  @override
  String get carrierTls => '安全連線失敗';

  @override
  String get carrierForbidden => '伺服器拒絕了這支手機';

  @override
  String get carrierNotFound => '伺服器上找不到這次配對或中繼端點';

  @override
  String get carrierCredentialsUnavailable => '暫時無法確認登入狀態';

  @override
  String backendServer(String message) {
    return '$message';
  }

  @override
  String get backendNotSignedIn => '尚未登入';

  @override
  String get backendSessionExpired => '登入已逾時，請重新登入。';

  @override
  String backendUnreachable(String base) {
    return '無法連線到伺服器（$base）';
  }

  @override
  String backendInsecure(String base) {
    return '$base 是未加密的 http://，登入憑證會以明文經過網際網路。請使用伺服器的 https:// 位址。';
  }

  @override
  String backendHttp(int status) {
    return '伺服器回傳 HTTP $status';
  }

  @override
  String backendRefreshFailed(int status) {
    return '暫時無法更新登入狀態（HTTP $status），請稍後再試';
  }

  @override
  String backendRefreshFailedIn(int status, int seconds) {
    return '暫時無法更新登入狀態（HTTP $status），請於 $seconds 秒後再試';
  }

  @override
  String backendUnparsable(String base) {
    return '伺服器回傳了無法解析的內容（$base 是不是填錯了？）';
  }

  @override
  String get backendBadData => '伺服器回傳的資料格式不正確';

  @override
  String get backendNoCredentials => '登入失敗：伺服器沒有回傳憑證';

  @override
  String get backendVerificationIncomplete => '登入需要第二步驗證，但伺服器沒有提供驗證流程';

  @override
  String get backendVerifyFailed => '驗證碼錯誤或已逾時';

  @override
  String get backendRateLimited => '請求太頻繁，請稍後再試';

  @override
  String backendRateLimitedIn(int seconds) {
    return '請求太頻繁，請於 $seconds 秒後再試';
  }

  @override
  String get pairErrNotSignedIn => '請先登入';

  @override
  String pairErrWrongBackend(String server, String signedIn) {
    return '這個 QR 碼屬於 $server，而你登入的是 $signedIn。兩端必須登入同一個伺服器。';
  }

  @override
  String get pairErrNoTicket => '伺服器沒有提供配對憑證，請重新產生 QR 碼';

  @override
  String pairErrNoGrant(String error) {
    return '這支手機已在這台電腦上登記，但取不到存取憑證（$error）。請在電腦上確認它是否已被撤銷；若已撤銷，請重新產生 QR 碼。';
  }

  @override
  String pairErrCleanup(String error) {
    return '無法清除這支手機在伺服器上的舊記錄（$error）';
  }

  @override
  String get pairCodeInvalid => '配對碼無效';

  @override
  String get pairCodeAppTooOld => '這個配對碼需要更新版本的手機端';

  @override
  String get pairCodeUnsupported => '不支援這個配對碼版本';

  @override
  String get pairCodeBadKey => '配對碼中的電腦公開金鑰無效';

  @override
  String get tabModels => '模型';

  @override
  String get modelsTitle => '模型';

  @override
  String get modelsReadOnlyTitle => '唯讀';

  @override
  String get modelsReadOnlyBody => '要在這支手機上修改模型與帳號，請在電腦的「遠端存取」中為它開啟「模型與帳號」權限。';

  @override
  String get modelsReadOnlyUnsupported => '這台電腦使用的伺服器還不支援從手機修改模型與帳號，這裡只能檢視。';

  @override
  String get modelsReadOnlyOldComputer =>
      '這台電腦上的 SkidSense 還不支援從手機修改這些設定：在電腦上更新後就能在這裡修改。';

  @override
  String get modelsRoute => '線路';

  @override
  String get modelsRouteHint => '代理的請求走哪條線路。切換會影響這台電腦上的所有對話。';

  @override
  String get modelsLocalMode => '本機';

  @override
  String get modelsLocalModeHint => '使用本機上各代理自己的帳號與訂閱，不經過第一方服務。';

  @override
  String get modelsCloudMode => '雲端';

  @override
  String get modelsCloudModeHint => '所有代理都經過你的第一方帳號，只使用你在 API Key 中分配的模型。';

  @override
  String get modelsSwitch => '切換';

  @override
  String get modelsSwitchCloudTitle => '切換到雲端？';

  @override
  String get modelsSwitchCloudBody =>
      '這會影響這台電腦上的所有對話：從下一個回合起，所有代理都經過你的第一方帳號，只使用分配給它的模型。';

  @override
  String get modelsSwitchLocalTitle => '切換回本機？';

  @override
  String get modelsSwitchLocalBody =>
      '這會影響這台電腦上的所有對話：從下一個回合起，每個代理都使用「本機帳號」中為它選的帳號。';

  @override
  String get modelsSwitchedCloud => '已切換到雲端';

  @override
  String get modelsSwitchedLocal => '已切換回本機';

  @override
  String get modelsSwitchRefused => '電腦沒有切換';

  @override
  String get modelsLocal => '本機帳號';

  @override
  String get modelsLocalHint => '本機模式下每個代理使用哪個帳號。只在電腦啟動它時注入，不會修改 CLI 自己的設定檔。';

  @override
  String get modelsLocalCloudNote => '目前是雲端模式，使用第一方帳號；這裡的選擇切換回本機模式後生效。';

  @override
  String get modelsLoading => '正在讀取電腦的模型與帳號…';

  @override
  String get modelsNoHarnesses => '這台電腦上沒有可以選擇帳號的代理。';

  @override
  String get modelsNotInstalled => '未安裝';

  @override
  String get modelsNotDriven => '尚未支援';

  @override
  String get modelsChoiceCli => '依照 CLI 自己的設定';

  @override
  String get modelsChoiceOfficial => '官方訂閱（強制）';

  @override
  String get modelsChoiceGone => '帳號已刪除';

  @override
  String get modelsRouteCli => '由 CLI 自己的設定決定（例如 cc-switch 寫入的設定檔）';

  @override
  String get modelsRouteOfficial =>
      '強制使用 Anthropic 官方訂閱登入，蓋過 settings.json 中的第三方端點';

  @override
  String get modelsRouteModelByCli => '由 CLI 決定模型';

  @override
  String get modelsNoKeyStored => '未儲存 Key';

  @override
  String modelsChoiceTitle(String agent) {
    return '$agent 的帳號';
  }

  @override
  String modelsChoiceHint(String dialect) {
    return '可選用 $dialect 協定的帳號';
  }

  @override
  String modelsChoiceNone(String dialect) {
    return '還沒有 $dialect 協定的帳號。';
  }

  @override
  String get modelsAccounts => '帳號';

  @override
  String get modelsAccountsHint =>
      '從預設新增 DeepSeek、智譜、Kimi、OpenRouter 等，或填入自己的轉發站。Key 存在電腦的系統鑰匙圈中。';

  @override
  String get modelsAccountsHintReadOnly => '電腦上的服務商帳號。Key 存在電腦的系統鑰匙圈中。';

  @override
  String get modelsNoAccounts => '還沒有帳號。新增一個：選個預設、填入 Key 就能使用。';

  @override
  String get modelsAddAccount => '新增帳號';

  @override
  String get modelsLegacy => '舊版端點';

  @override
  String get modelsLegacyHint => '選擇協定後可設為帳號';

  @override
  String modelsPresetTag(String preset) {
    return '$preset 預設';
  }

  @override
  String get modelsKeyStored => '已儲存 Key';

  @override
  String get modelsKeyMissing => '沒有 Key';

  @override
  String modelsDialectModels(String dialect, int count) {
    return '$dialect（$count 個模型）';
  }

  @override
  String modelsDeleteAccountTitle(String name) {
    return '刪除帳號「$name」？';
  }

  @override
  String get modelsDeleteAccountBody =>
      '它的 Key 會一併從鑰匙圈刪除；正在使用它的代理會回到「依照 CLI 自己的設定」。';

  @override
  String modelsAccountDeleted(String name) {
    return '已刪除「$name」';
  }

  @override
  String get modelsDeleteConflict => '這個帳號已在別處修改，已重新讀取。確認後如仍要刪除，請再操作一次。';

  @override
  String get modelsCloud => '雲端 API Key';

  @override
  String get modelsCloudHint =>
      '雲端模式靠它們：選一把 Key「分配模型」，把它能用的模型分給各個代理。使用這支手機自己的登入管理。';

  @override
  String get keysLoading => '正在讀取 Key…';

  @override
  String get keysEmpty => '還沒有 Key，建立一把才能使用雲端模式。';

  @override
  String get keyUnnamed => '未命名';

  @override
  String get assignUnnamedKey => '第一方 Key';

  @override
  String get keyUnlimited => '不限額度';

  @override
  String keyRemaining(String amount) {
    return '剩餘 $amount';
  }

  @override
  String keyGroupNamed(String group) {
    return '群組 $group';
  }

  @override
  String get keyGroupDefault => '依照帳號預設';

  @override
  String get keyDisabled => '已停用';

  @override
  String get keyExpired => '已過期';

  @override
  String get keyExhausted => '額度用完';

  @override
  String get keyAssign => '分配模型';

  @override
  String get keyReveal => '顯示完整 Key';

  @override
  String get keyCreate => '建立 Key';

  @override
  String get keyCreateTitle => '建立 API Key';

  @override
  String get keyCreateHint => '使用這支手機的登入在你的帳號中建立，不經過電腦。';

  @override
  String get keyName => '名稱';

  @override
  String get keyNameHint => '例如 我的筆電';

  @override
  String get keyNameRequired => '為這把 Key 取個名字';

  @override
  String keyNameTooLong(int letters, int chinese) {
    return '名稱太長：最多 $letters 個英文字母或 $chinese 個中文字';
  }

  @override
  String get keyGroup => '群組';

  @override
  String get keyGroupsLoading => '正在讀取群組…';

  @override
  String get keyUnlimitedHint => '從帳號餘額扣款，這把 Key 本身不設上限';

  @override
  String get keyQuota => '額度（美元）';

  @override
  String get keyQuotaInvalid => '請填入大於 0 的金額';

  @override
  String get keyExpiry => '有效期限';

  @override
  String get keyExpiryNever => '永不過期';

  @override
  String keyExpiryDays(int days) {
    return '$days 天';
  }

  @override
  String get keyCreatedTitle => 'Key 已建立';

  @override
  String get keyShownOnce => '這是完整的 Key，只顯示這一次。';

  @override
  String keyRevealTitle(String name) {
    return 'Key「$name」';
  }

  @override
  String get keyRevealHint => '請妥善保管：拿到它的人就能使用你的額度。';

  @override
  String get keyRevealReason => '解鎖以顯示完整 Key';

  @override
  String keyDeleteTitle(String name) {
    return '刪除 Key「$name」？';
  }

  @override
  String get keyDeleteBody => '使用它的地方都會失效，包括用它建立的雲端分配。刪除後無法復原。';

  @override
  String get modelsAssigned => '已分配給代理';

  @override
  String get modelsAssignedHint => '雲端模式下各代理使用的分配。';

  @override
  String get modelsNoModelsAssigned => '未指定模型';

  @override
  String get modelsUnassign => '取消分配';

  @override
  String modelsUnassignTitle(String name) {
    return '取消分配「$name」？';
  }

  @override
  String get modelsUnassignBody => '雲端模式下這個代理就不能再使用這些模型；Key 本身會保留。';

  @override
  String modelsUnassigned(String name) {
    return '已取消分配「$name」';
  }

  @override
  String get assignTitle => '分配模型';

  @override
  String assignHint(String key) {
    return '勾選模型，並選擇分配給哪個代理；雲端模式就使用這些分配。每項顯示為「代理 · $key」。';
  }

  @override
  String get assignTo => '目前分配給';

  @override
  String get assignToHint => '之後勾選的模型會歸到這個代理；換一個再勾選即可分給多個。';

  @override
  String get assignToOnlyHint => '之後勾選的模型會歸到這個代理；這台電腦上只有這一個代理。';

  @override
  String get assignAgentsLoading => '正在讀取電腦上的代理…';

  @override
  String get assignAgentsFailed => '無法讀取電腦上的代理';

  @override
  String get assignNoAgents => '這台電腦上沒有已安裝且已支援的代理。';

  @override
  String get assignSearch => '搜尋模型';

  @override
  String get assignLoading => '正在取得這把 Key 的模型清單…';

  @override
  String get assignNoModels => '這把 Key 沒有回傳任何模型。';

  @override
  String assignGoesTo(String agents) {
    return '分配給 $agents';
  }

  @override
  String assignSummary(String agent, int count, int places) {
    return '$agent：已勾選 $count 個模型 · 共 $places 處分配';
  }

  @override
  String get assignConfirm => '確認';

  @override
  String get assignNoneSelected => '至少勾選一個模型';

  @override
  String assignTooMany(int limit) {
    return '每個代理一次最多分配 $limit 個模型';
  }

  @override
  String assignPartial(String made, String error) {
    return '只完成了一部分。已建立：$made。之後失敗：$error';
  }

  @override
  String assignDone(int count) {
    return '已為 $count 個代理設定好';
  }

  @override
  String get ctxTitle => '上下文與自動壓縮';

  @override
  String get ctxEntry => '每個模型的壓縮門檻';

  @override
  String get ctxEntryHint => '上下文超過你設定的大小才自動壓縮';

  @override
  String ctxHint(String min, String max) {
    return '為每個模型設定一個大小（$min–$max）：上下文超過它才自動壓縮，未超過就不壓縮。沒設定的模型照舊由代理自己決定。視窗是模型能容納的上限。';
  }

  @override
  String get ctxLoading => '正在讀取模型…';

  @override
  String get ctxEmpty => '還沒有可設定的模型。';

  @override
  String ctxCliGroup(String agent) {
    return '$agent 內建';
  }

  @override
  String ctxCloudGroup(String agent, String key) {
    return '$agent · 雲端 Key「$key」';
  }

  @override
  String get ctxDefaultModel => '預設模型';

  @override
  String get ctxNoAgents => '還沒有能使用它的代理。';

  @override
  String ctxSupportLine(String agents, String support) {
    return '$agents：$support';
  }

  @override
  String get ctxSupportNative => '到門檻時自動壓縮';

  @override
  String get ctxSupportManaged => '在回合之間判斷，超過就先壓縮再傳送訊息';

  @override
  String get ctxSupportUnsupported => '不支援設定，由它自己決定';

  @override
  String ctxWindow(String size, String source) {
    return '視窗 $size · $source';
  }

  @override
  String get ctxSourceCustom => '你設定的';

  @override
  String get ctxSourceDiscovered => '端點回報';

  @override
  String get ctxSourcePreset => '帳號預設';

  @override
  String get ctxSourceKnown => '型號預設';

  @override
  String get ctxSourceEstimate => '估計';

  @override
  String get ctxDefault => '預設';

  @override
  String ctxSliderLabel(String model) {
    return '$model 的壓縮門檻';
  }

  @override
  String ctxCustom(String size) {
    return '上下文超過 $size 時自動壓縮，未超過不壓縮。';
  }

  @override
  String get ctxDefaultState => '預設：由代理自己決定。';

  @override
  String ctxOverWindow(String window) {
    return '比視窗 $window 還大：視窗裝滿前代理會自己壓縮，視窗不對可以修改。';
  }

  @override
  String get ctxEditWindow => '修改視窗大小';

  @override
  String get ctxResetWindow => '恢復推算的視窗';

  @override
  String get ctxReset => '恢復預設';

  @override
  String get ctxWindowField => '視窗，例如 200k、1m 或 200000';

  @override
  String get ctxWindowInvalid => '視窗請寫成 200k、1m 或 200000 這樣的數字（1K–100M）';

  @override
  String get editorAddTitle => '新增帳號';

  @override
  String get editorEditTitle => '編輯帳號';

  @override
  String get editorAdd => '新增';

  @override
  String editorSaved(String name) {
    return '已儲存「$name」';
  }

  @override
  String editorAdded(String name) {
    return '已新增「$name」，到「本機帳號」為代理選用它';
  }

  @override
  String get editorPreset => '預設';

  @override
  String get editorPresetHint => '選一個預設會填好各協定的位址與模型。模型名稱經常更新，儲存前可用「取得模型」更新。';

  @override
  String get editorPresetSearch => '搜尋供應商';

  @override
  String get editorPresetsLoading => '正在讀取預設…';

  @override
  String get editorPresetCredit => '部分預設來自 cc-switch，依 MIT 授權使用。';

  @override
  String get editorPresetLicense => '授權聲明';

  @override
  String get editorPresetCustom => '自訂';

  @override
  String get editorAccountSection => '帳號';

  @override
  String get editorName => '名稱';

  @override
  String get editorNameHint => '例如 DeepSeek（個人）';

  @override
  String get editorNameRequired => '為帳號取個名字';

  @override
  String get editorNote => '備註';

  @override
  String get editorNoteHint => '誰的 Key、用途、計費方式…';

  @override
  String get editorApiKey => 'API Key';

  @override
  String get editorKeyShared => '所有協定共用，存入電腦的系統鑰匙圈，之後不再顯示。';

  @override
  String get editorKeyKept => '所有協定共用。已儲存 Key，留空表示不修改。';

  @override
  String get editorKeyWillClear => '儲存時會清除已儲存的 Key。';

  @override
  String get editorClearKey => '清除已儲存的 Key';

  @override
  String get editorClearKeyHint => '給不需要 Key 的端點使用';

  @override
  String get editorProtocols => '協定端點';

  @override
  String get editorProtocolsHint => '一個供應商一個帳號：依它支援的協定分別填寫端點，共用一把 Key。';

  @override
  String get editorNoProtocol => '至少開啟一個協定端點';

  @override
  String editorDialectFor(String agents) {
    return '給 $agents 使用';
  }

  @override
  String get editorBaseUrl => 'Base URL';

  @override
  String get editorUrlRequired => '請填寫 Base URL';

  @override
  String get editorUrlNotAddress => '不是有效的位址，例如 https://api.example.com/v1';

  @override
  String get editorUrlNotHttp => '必須以 http:// 或 https:// 開頭';

  @override
  String get editorModels => '模型';

  @override
  String get editorModelsHint => '「取得模型」直接向端點取得它的模型清單。';

  @override
  String get editorFetch => '取得模型';

  @override
  String get editorModelList => '模型 ID';

  @override
  String get editorModelsHelper => '每行一個，或用逗號分隔';

  @override
  String get editorCodexNeedsModel => 'Codex 使用的這個端點至少要有一個模型：填入模型 ID，或設定預設模型';

  @override
  String get editorFetching => '正在向端點取得模型清單…';

  @override
  String get editorFetchFailed => '無法取得模型';

  @override
  String editorFetched(int count) {
    return '取得 $count 個模型，已填入清單。';
  }

  @override
  String editorFetchedSome(int count, int kept) {
    return '取得 $count 個模型，已填入前 $kept 個（每個協定最多 $kept 個）。';
  }

  @override
  String get editorFetchNeedsUrl => '請先填寫 Base URL';

  @override
  String get editorFetchNoQuery => '位址中不能有 ? 或 #：模型清單的路徑要接在它後面';

  @override
  String editorFetchRejected(int status) {
    return '金鑰被拒絕（$status），請檢查這個端點的 Key';
  }

  @override
  String editorFetchHttp(int status) {
    return '端點回應 HTTP $status';
  }

  @override
  String get editorFetchTimeout => '端點 20 秒內沒有回應';

  @override
  String get editorFetchNetwork => '連不上這個位址';

  @override
  String get editorFetchNotJson => '端點的回應不是 JSON';

  @override
  String get editorFetchEmpty => '端點沒有列出任何模型';

  @override
  String get editorFetchTooLarge => '端點的回應太大（超過 8 MiB）';

  @override
  String get editorModelMap => '模型對應';

  @override
  String get editorModelMapHint => '代理預設使用哪個模型。';

  @override
  String get editorModelMapHintAnthropic => 'Claude Code 的各個槽位使用哪個模型；留空的同主模型。';

  @override
  String get editorSlotMain => '主模型';

  @override
  String get editorSlotDefault => '預設模型';

  @override
  String get editorSlotHaiku => 'Haiku（背景）';

  @override
  String get editorSlotSubagent => '子代理';

  @override
  String get editorSameAsMain => '同主模型';

  @override
  String get editorPickModel => '從清單選擇';

  @override
  String get editorExtraEnv => '額外環境變數';

  @override
  String get editorExtraEnvHint =>
      '只注入 Claude Code。端點、Key 這類變數由路由本身管理，不能在這裡覆蓋。';

  @override
  String get editorExtraEnvField => '變數';

  @override
  String get editorExtraEnvFormat => '每行一個 KEY=VALUE';

  @override
  String editorEnvLine(String line) {
    return '不是 KEY=VALUE：$line';
  }

  @override
  String editorEnvBadName(String name) {
    return '「$name」不是有效的環境變數名稱（以大寫字母開頭，只能有大寫字母、數字、底線）';
  }

  @override
  String editorEnvReserved(String name) {
    return '「$name」由路由本身管理，不能在帳號裡覆蓋';
  }

  @override
  String get editorAdopt => '併入舊版端點';

  @override
  String editorAdopted(String name) {
    return '併入舊版端點「$name」';
  }

  @override
  String get editorAdoptUndo => '不併入';

  @override
  String get editorAdoptHint => '選一個舊版端點和它使用的協定：它會成為這個帳號在該協定的端點，Key 一起帶過來。';

  @override
  String get editorAdoptProtocol => '它使用的協定';

  @override
  String get editorAdoptAction => '併入';

  @override
  String get editorLegacyTitle => '舊版端點';

  @override
  String get editorLegacyBody => '它是在帳號功能之前建立的，沒有標明協定。開啟它使用的協定，儲存後就成為帳號。';

  @override
  String get editorConflictTitle => '在別處被修改了';

  @override
  String get editorConflictBody => '你編輯時，電腦或另一台裝置修改了這個帳號。重新載入會捨棄這裡的修改。';

  @override
  String get editorReload => '重新載入';

  @override
  String editorReloadFailed(String error) {
    return '重新讀取失敗：$error';
  }

  @override
  String get editorDeletedElsewhere => '這個帳號已在別處刪除。';

  @override
  String get editorKeyRequired => '換了伺服器位址，需要重新填寫 API Key';

  @override
  String get editorKeyRequiredBody =>
      '已儲存的 Key 不能帶到新的位址。重新填寫 API Key，或清除已儲存的 Key，再儲存。';

  @override
  String editorFixFields(int count) {
    return '有 $count 處需要修改';
  }

  @override
  String get editorStatusConflict => '這個帳號在別處被修改過：到頂端重新載入';

  @override
  String get editorStatusRefused => '沒有儲存：原因見頂端';

  @override
  String editorTooLong(int limit) {
    return '最多 $limit 個字元';
  }

  @override
  String editorTooMany(int limit) {
    return '最多 $limit 項';
  }

  @override
  String editorTooManyModels(int limit) {
    return '最多 $limit 個模型';
  }

  @override
  String editorTooManyEnv(int limit) {
    return '最多 $limit 個變數';
  }

  @override
  String get editorEmpty => '不能空白';

  @override
  String get editorKeyInvalid => '只能是可列印的 ASCII 字元，不能有空格';

  @override
  String get editorUrlInvalid => '不能有空白或控制字元';

  @override
  String get editorControlChars => '不能含控制字元';

  @override
  String editorProblemIn(String item, String problem) {
    return '$item：$problem';
  }

  @override
  String get editorDiscardTitle => '捨棄修改？';

  @override
  String get editorDiscardBody => '這裡的修改還沒有儲存。';

  @override
  String get editorUnknownProtocol =>
      '這個帳號使用了這個版本的 App 不認識的協定：請在電腦上編輯，或更新 App。';

  @override
  String editorProtocolTwice(String protocol) {
    return '$protocol 端點重複了';
  }

  @override
  String get errProviderUnsupported => '這台電腦不支援指定帳號的模型，請重新選擇模型。';

  @override
  String get backendKeyNotLocated => 'Key 已建立，但之後的清單中找不到它。建立另一把之前，請先查看現有的 Key。';

  @override
  String get backendNoKey => '伺服器沒有回傳 Key';
}
