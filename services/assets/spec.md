# Atomic Asset

**Status:** Draft

**Version:** 0.0.1

**Authors:** Nick Juliano (nick@arweave.org)

## Introduction

This document specifies atomic assets on AO / Arweave. An atomic asset is a unique digital item consisting of an AO process and its associated data which are stored together in a single transaction on Arweave. Atomic assets are ownable and transferable tokens which follow the [AO Token Blueprint](https://cookbook_ao.arweave.net/guides/aos/blueprints/token.html), while also including additional data and metadata that can be used to represent a wide variety of digital assets.

## Motivation

As atomic assets serve as a foundational building block for the permaweb, a clear specification is required to ensure consistency and interoperability across different implementations. Atomic assets provide a standardized way to represent ownable and tradeable items which can art, music, videos, applications, domain names, and more.

## Specification

An atomic asset must consist of the following components:

- An AO process which follows the [AO Token Blueprint](https://cookbook_ao.arweave.net/guides/aos/blueprints/token.html)
- Metadata to describe the asset which follows the [ANS-110 Standard](https://github.com/ArweaveTeam/arweave-standards/blob/master/ans/ANS-110.md)
- Data which represents the asset itself