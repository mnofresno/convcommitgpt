import pytest
from pathlib import Path
from unittest.mock import Mock, patch
from convcommitgpt.diff_generator import DiffGenerator

@pytest.fixture
def mock_git_diff():
    return """diff --git a/test.py b/test.py
index 1234567..89abcde 100644
--- a/test.py
+++ b/test.py
@@ -1,2 +1,3 @@
 def test():
-    return True
+    return False
"""

@pytest.fixture
def diff_generator():
    return DiffGenerator(max_bytes=1024)

@patch('diff_generator.subprocess.run')
def test_generate_diff_success(mock_run, diff_generator, mock_git_diff):
    mock_run.return_value = Mock(
        returncode=0,
        stdout=mock_git_diff.encode(),
        stderr=b''
    )
    
    result = diff_generator.generate(Path("/test/repo"))
    
    assert result == mock_git_diff
    mock_run.assert_called_once()

@patch('diff_generator.subprocess.run')
def test_generate_diff_error(mock_run, diff_generator):
    mock_run.return_value = Mock(
        returncode=1,
        stdout=b'',
        stderr=b'Error: not a git repository'
    )
    
    with pytest.raises(Exception) as exc_info:
        diff_generator.generate(Path("/test/repo"))
    
    assert "Error: not a git repository" in str(exc_info.value)

def test_max_bytes_limit(diff_generator):
    long_diff = "x" * 2000
    result = diff_generator._limit_diff_size(long_diff)
    assert len(result) <= 1024 