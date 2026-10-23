"""Validate the lists committed to the repository, as users download them."""

from conftest import REPO
from validate_outputs import Validator


def test_published_outputs_are_valid():
    assert Validator(str(REPO)).run() == []
