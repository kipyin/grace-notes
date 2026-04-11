"""Exponential backoff with jitter for subprocess and HTTP calls."""

from __future__ import annotations

import random
import time
from collections.abc import Callable, Iterator
from typing import TypeVar

T = TypeVar("T")


def retry_call(
    fn: Callable[[], T],
    *,
    max_attempts: int,
    base_seconds: float,
    is_retryable: Callable[[BaseException], bool] | None = None,
) -> T:
    """Run ``fn`` until success or attempts exhausted."""
    last: BaseException | None = None
    for attempt in range(max_attempts):
        try:
            return fn()
        except BaseException as exc:
            last = exc
            if is_retryable is not None and not is_retryable(exc):
                raise
            if attempt == max_attempts - 1:
                raise
            delay = base_seconds * (2**attempt) + random.uniform(0, base_seconds)
            time.sleep(delay)
    assert last is not None
    raise last


def backoff_delays(
    *,
    max_attempts: int,
    base_seconds: float,
) -> Iterator[float]:
    """Yield sleep durations for each retry after a failure (for manual loops)."""
    for attempt in range(max_attempts - 1):
        yield base_seconds * (2**attempt) + random.uniform(0, base_seconds)
