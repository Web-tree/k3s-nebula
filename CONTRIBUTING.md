# Contributing to k3s-nebula

First off, thanks for taking the time to contribute!

## How to Contribute

### Reporting Bugs

This section guides you through submitting a bug report for k3s-nebula. Following these guidelines helps maintainers and the community understand your report, reproduce the behavior, and find related reports.

- **Use a clear and descriptive title** for the issue to identify the problem.
- **Describe the exact steps which reproduce the problem** in as many details as possible.
- **Provide specific examples** to demonstrate the steps.

### Pull Requests

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Development Setup

See [DEVELOPER.md](../DEVELOPER.md) for detailed instructions on setting up your local environment.

## Styleguides

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

### Terraform Style

- Always run `terraform fmt` before committing.
- Use `snake_case` for resource names.
- Document variables with descriptions and types.
