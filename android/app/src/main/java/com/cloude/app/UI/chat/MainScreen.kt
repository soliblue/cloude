package com.cloude.app.UI.chat

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import com.cloude.app.Models.WindowType
import com.cloude.app.Services.ChatViewModel
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Services.WindowManager
import com.cloude.app.UI.files.FileBrowserScreen
import com.cloude.app.UI.git.GitScreen

@Composable
fun MainScreen(
    windowManager: WindowManager,
    viewModel: ChatViewModel,
    connectionManager: ConnectionManager,
    environmentId: String,
    workingDirectory: String,
    modifier: Modifier = Modifier
) {
    val windows by windowManager.windows.collectAsState()
    val activeIndex by windowManager.activeIndex.collectAsState()

    val pagerState = rememberPagerState(
        initialPage = activeIndex,
        pageCount = { windows.size }
    )

    LaunchedEffect(activeIndex) {
        if (pagerState.currentPage != activeIndex) {
            pagerState.animateScrollToPage(activeIndex)
        }
    }

    LaunchedEffect(pagerState) {
        snapshotFlow { pagerState.currentPage }.collect { page ->
            windowManager.setActive(page)
        }
    }

    val activeWindow = windows.getOrNull(activeIndex)

    Column(modifier = modifier.fillMaxSize().imePadding()) {
        WindowTabBar(
            activeType = activeWindow?.type ?: WindowType.Chat,
            onTypeSelected = { type ->
                activeWindow?.let { windowManager.setWindowType(it.id, type) }
            }
        )

        PageIndicator(
            windows = windows,
            activeIndex = activeIndex,
            canAdd = windows.size < 5,
            onPageSelected = { windowManager.setActive(it) },
            onAddWindow = { windowManager.addWindow() },
            onRemoveWindow = { windowManager.removeWindow(it) },
            modifier = Modifier.fillMaxWidth()
        )

        HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

        HorizontalPager(
            state = pagerState,
            modifier = Modifier.weight(1f),
            beyondViewportPageCount = 1
        ) { page ->
            val window = windows.getOrNull(page) ?: return@HorizontalPager
            when (window.type) {
                WindowType.Chat -> ChatScreen(
                    viewModel = viewModel,
                    connectionManager = connectionManager,
                    environmentId = environmentId,
                    modifier = Modifier.fillMaxSize()
                )
                WindowType.Files -> FileBrowserScreen(
                    connectionManager = connectionManager,
                    environmentId = environmentId,
                    initialPath = workingDirectory,
                    modifier = Modifier.fillMaxSize()
                )
                WindowType.GitChanges -> GitScreen(
                    connectionManager = connectionManager,
                    environmentId = environmentId,
                    workingDirectory = workingDirectory,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}
