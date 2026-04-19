# EnvironmentConnection — one-file view

```
EnvironmentConnection
│
├── state
│   ├── environmentId             which Mac/Linux agent this is
│   ├── phase                     disconnected / connected / authenticated
│   ├── isWhisperReady            server told us whisper is ready to transcribe
│   ├── isTranscribing            a transcription request is in flight
│   ├── agentState                idle / running / compacting
│   ├── lastError                 last failure string, shown in UI
│   ├── defaultWorkingDirectory   where to run things if nobody says
│   ├── skills                    available skills from the agent
│   ├── chunkProgress             "we're at chunk 3/8 of some file"
│   ├── latencyMs                 ping time
│   ├── symbol                    SF Symbol shown for this environment
│   ├── gitStatus                 owned GitStatusService (queue + timeout)
│   ├── fileCache                 owned FileCache (LRU of file bytes)
│   ├── pendingChunks             partially-received file chunks
│   ├── interruptedSessions       sessions we need to resume on reconnect
│   ├── conversationOutputs       per-conversation streaming state map
│   ├── webSocket, session        the actual URLSession socket
│   ├── savedHost/Port/Token      credentials for reconnect
│   ├── connectionToken           generation id, used to drop stale callbacks
│   ├── manager                   weak ref back to EnvironmentStore
│   ├── id                        (computed) alias for environmentId
│   ├── hasCredentials            (computed) do we have host + token
│   └── runningOutputs            (computed) conversations not in .idle phase
│
├── lifecycle
│   ├── init(environmentId:)      wire gitStatus send + canSend callbacks
│   └── resetServerState()        wipe transient state on disconnect
│
├── networking
│   ├── connect(host,port,token)  save creds + reconnect
│   ├── reconnect()               open socket, phase=connected, start receive loop
│   ├── reconnectIfNeeded()       only if creds present and currently disconnected
│   ├── disconnect()              tear down socket, optionally clear creds
│   ├── handleDisconnect()        teardown path: flush running outputs, snapshot, reset
│   ├── authenticate()            send auth token
│   ├── send(message)             encode + send a ClientMessage (outgoing)
│   ├── receiveMessage(token)     recursive loop: pull next frame, dispatch, repeat
│   └── checkForMissedResponse()  ask server to resume interrupted sessions
│
├── outgoing client calls
│   ├── sendChat(...)             start a chat turn, prime output, send .chat
│   ├── abort(conversationId:)    send .abort for a conversation
│   ├── searchFiles(query,wd)     send .searchFiles
│   ├── listDirectory(path)       send .listDirectory
│   ├── getFile(path)             send .getFile
│   ├── getFileFullQuality(path)  send .getFileFullQuality
│   ├── gitLog(path,count)        send .gitLog
│   ├── gitDiff(path,file,staged) send .gitDiff
│   ├── syncHistory(sid,wd)       send .syncHistory
│   ├── transcribe(audioBase64)   flip isTranscribing, send .transcribe
│   └── requestNameSuggestion(..) send .suggestName for a conversation
│
├── output helpers
│   ├── output(for: convId)       get-or-create ConversationOutput for a conv
│   └── ensureRunning(out)        (private) flip .idle -> .running
│
└── incoming messages
    ├── handleMessage(text)             ROUTER - decode JSON, switch on message kind, then either
    │                                   call one of the handlers below OR handle inline in the switch.
    │
    ├── inline cases (handled directly in the switch, no dedicated function)
    │   ├── .authRequired               -> logs + calls authenticate()
    │   ├── .authResult                 -> logs + dispatches to handleAuthResult
    │   ├── .error                      -> logs, completes gitStatus in-flight, calls handleError
    │   ├── .whisperReady               -> sets isWhisperReady
    │   ├── .pong                       -> sets latencyMs (now - sentAt)
    │   ├── .defaultWorkingDirectory    -> sets defaultWorkingDirectory + emits event
    │   ├── .directoryListing           -> emits event
    │   ├── .fileThumbnail              -> emits event
    │   ├── .fileSearchResults          -> emits event
    │   ├── .gitDiffResult              -> emits event
    │   ├── .gitLogResult               -> emits event
    │   ├── .historySync                -> emits event
    │   ├── .historySyncError           -> emits event
    │   └── .gitCommitResult            -> no-op
    │
    └── handlers (one per server message kind; dispatched by handleMessage)
        ├── handleOutput                assistant text chunk arrived
        ├── handleStatus                agent state changed (running/compacting/idle)
        ├── handleAuthResult            auth succeeded or failed
        ├── handleError                 server sent an error
        ├── handleToolCall              a tool started executing
        ├── handleToolResult            a tool finished
        ├── handleRunStats              duration/cost/model for the turn
        ├── handleSessionId             server assigned us a session id
        ├── handleMessageUUID           server assigned message uuid
        ├── handleTranscription         whisper returned transcribed text
        ├── handleSkills                skill list arrived/updated
        ├── handleNameSuggestion        rename a conversation (+ optional symbol) from server suggestion
        ├── handleFileContent           single-response file bytes (cache + emit)
        ├── handleFileChunk             one chunk of a multi-part file
        ├── handleGitStatusResult       git status came back
        └── handleResumeFromResponse    replay events the server buffered while we were offline
```
