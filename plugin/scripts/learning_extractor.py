"""LLM-based preference extraction from user corrections.

This module detects corrections and extracts preferences from transcripts.
Currently uses simple keyword matching. Future versions will use LLM APIs.

TODO: Integrate Anthropic Claude API for actual LLM-based extraction
TODO: Add confidence scoring for extracted preferences
TODO: Implement multi-turn conversation analysis
"""

import logging
import re
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)


def extract_correction(event: Dict, transcript: str) -> Optional[Dict]:
    """Detect if a correction happened in the transcript.

    Args:
        event: Event dictionary containing stop event metadata
        transcript: Recent conversation transcript

    Returns:
        Dictionary with correction details if detected, None otherwise

    TODO: Replace keyword matching with LLM-based analysis
    TODO: Handle multi-message corrections
    TODO: Extract context around the correction
    """
    # Simple keyword-based detection for now
    correction_keywords = [
        "actually",
        "instead",
        "not that",
        "i meant",
        "correction",
        "wrong",
        "should be",
        "prefer",
        "use this",
        "don't use",
        "always use",
        "never use"
    ]

    transcript_lower = transcript.lower()

    # Check if any correction keyword is present
    for keyword in correction_keywords:
        if keyword in transcript_lower:
            logger.info(f"Detected potential correction with keyword: '{keyword}'")

            # Extract the sentence containing the keyword
            sentences = re.split(r'[.!?]', transcript)
            correction_text = None

            for sentence in sentences:
                if keyword in sentence.lower():
                    correction_text = sentence.strip()
                    break

            return {
                'detected': True,
                'keyword': keyword,
                'correction_text': correction_text or transcript,
                'confidence': 0.7,  # TODO: LLM-based confidence
                'event': event
            }

    logger.debug("No correction detected in transcript")
    return None


def extract_preference(correction_text: str) -> Optional[Dict]:
    """Extract a structured preference from correction text.

    Args:
        correction_text: Text containing the user's correction

    Returns:
        Dictionary with preference details if extracted, None otherwise

    TODO: Use LLM to extract structured preference
    TODO: Handle complex multi-part preferences
    TODO: Extract rationale for the preference
    """
    # Simple pattern matching for now
    patterns = [
        # "use X instead of Y"
        (r"use\s+(.+?)\s+instead of\s+(.+)", "prefer_over"),
        # "prefer X"
        (r"prefer\s+(.+)", "prefer"),
        # "always use X"
        (r"always use\s+(.+)", "always"),
        # "never use X"
        (r"never use\s+(.+)", "never"),
        # "don't use X"
        (r"don't use\s+(.+)", "avoid"),
    ]

    text_lower = correction_text.lower()

    for pattern, pref_type in patterns:
        match = re.search(pattern, text_lower)
        if match:
            logger.info(f"Extracted preference type: {pref_type}")

            if pref_type == "prefer_over":
                return {
                    'type': pref_type,
                    'preferred': match.group(1).strip(),
                    'avoided': match.group(2).strip(),
                    'raw_text': correction_text,
                    'confidence': 0.6  # TODO: LLM-based confidence
                }
            else:
                return {
                    'type': pref_type,
                    'subject': match.group(1).strip(),
                    'raw_text': correction_text,
                    'confidence': 0.6  # TODO: LLM-based confidence
                }

    logger.debug("Could not extract structured preference")
    return None


def classify_scope(preference: Dict, project_path: str) -> str:
    """Classify whether a preference is global, language-specific, or project-specific.

    Args:
        preference: Preference dictionary
        project_path: Path to the current project

    Returns:
        Scope classification: 'global', 'language', or 'project'

    TODO: Use LLM to analyze preference context
    TODO: Consider project structure and language files
    TODO: Auto-promote patterns when they appear in multiple projects
    """
    # Simple heuristics for now
    raw_text = preference.get('raw_text', '').lower()

    # Language-specific keywords
    language_keywords = [
        'python', 'javascript', 'typescript', 'java', 'rust', 'go',
        'react', 'vue', 'angular', 'django', 'flask', 'fastapi',
        'pip', 'npm', 'cargo', 'maven', 'gradle'
    ]

    for keyword in language_keywords:
        if keyword in raw_text:
            logger.info(f"Classified as 'language' scope due to keyword: {keyword}")
            return 'language'

    # Project-specific indicators
    project_keywords = [
        'this project', 'this codebase', 'this repo',
        'here', 'for this', 'in this'
    ]

    for keyword in project_keywords:
        if keyword in raw_text:
            logger.info(f"Classified as 'project' scope due to keyword: {keyword}")
            return 'project'

    # Global by default (conservative choice)
    logger.info("Classified as 'project' scope (default - conservative)")
    return 'project'  # Default to project to avoid overgeneralization


# TODO: Future LLM integration functions

def _call_llm_for_correction_detection(transcript: str) -> Dict:
    """Call LLM to detect corrections in transcript.

    TODO: Implement using Anthropic Claude API
    TODO: Design prompt for correction detection
    TODO: Handle API errors and retries
    """
    raise NotImplementedError("LLM integration not yet implemented")


def _call_llm_for_preference_extraction(correction_text: str) -> Dict:
    """Call LLM to extract structured preference.

    TODO: Implement using Anthropic Claude API
    TODO: Design prompt for preference extraction
    TODO: Handle edge cases and ambiguous corrections
    """
    raise NotImplementedError("LLM integration not yet implemented")


def _call_llm_for_scope_classification(preference: Dict, project_context: str) -> str:
    """Call LLM to classify preference scope.

    TODO: Implement using Anthropic Claude API
    TODO: Design prompt for scope classification
    TODO: Consider project structure and history
    """
    raise NotImplementedError("LLM integration not yet implemented")
