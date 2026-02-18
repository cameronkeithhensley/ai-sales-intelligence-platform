# AI Sales Intelligence Platform

Multi-tenant SaaS platform delivering AI-powered intent signals for outbound sales teams.

## Architecture

- **AWS ECS Fargate** — containerized, horizontally scalable agent cluster
- **RDS PostgreSQL** — schema-per-tenant multi-tenancy
- **Terraform** — all infrastructure as code
- **CI/CD** — GitHub Actions → Terraform → ECS

## Agents

| Agent | Purpose |
|-------|---------|
| Scout | Discovers intent signals from public sources |
| Profiler | Builds OSINT-based prospect dossiers (passive only) |
| Writer | Generates personalized outreach |
| Holdsworth | AI butler — primary user interface |

## Repository Structure

This is the **public portfolio repo** containing sanitized infrastructure code and architecture documentation.

## Tech Stack

Terraform · AWS ECS Fargate · RDS PostgreSQL · Python · Docker · GitHub Actions
