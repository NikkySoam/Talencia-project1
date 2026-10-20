# Talentra — Profile Entity List

**Backlog:** B4  
**Owner:** Whole team  
**Status:** Draft for validation under B5

## 1. Candidate Profile

| Entity | Purpose |
|---|---|
| `candidate_profile` | Core candidate profile and personal details |
| `candidate_education` | Candidate's education history |
| `candidate_experience` | Candidate's work experience |
| `candidate_skill` | Skills associated with a candidate |
| `candidate_language` | Languages known by a candidate |
| `candidate_project` | Projects completed by a candidate |

## 2. Resume Management

| Entity | Purpose |
|---|---|
| `resume_version` | Different versions of a candidate's resume |
| `resume_template` | Resume templates available to candidates |

## 3. Assessments and Learning

| Entity | Purpose |
|---|---|
| `assessment` | Assessment definitions |
| `assessment_score` | Candidate assessment results |
| `course_enrolment` | Candidate course enrolments |

## 4. Profile History and Activity

| Entity | Purpose |
|---|---|
| `profile_view_history` | Records of candidate profile views |
| `candidate_activity_log` | Candidate activity, such as profile updates |
| `candidate_shortlist` | Shortlist or bookmark history for candidates |
| `referral` | Referral tracking records |

## 5. Shared Master Data Dependencies

The Profile module references shared master data, including:

- `skill`
- `language`
- `qualification`
- `country`
- `state`
- `city`

These entities are part of the common Master Data design and should not be independently duplicated inside Profile.

## Validation notes

This is the initial entity proposal. The team must compare it with the Profile scope in the hackathon docket, confirm any missing entities, and document any justified omissions before marking B4 and B5 complete.