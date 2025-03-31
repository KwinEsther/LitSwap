# LitSwap: P2P Book Exchange Protocol

LitSwap is a decentralized peer-to-peer protocol built on Clarity that enables users to list, discover, and exchange books with others in their community.

## Overview

LitSwap creates a decentralized marketplace for book enthusiasts to share their collections with others. The protocol allows users to list books they're willing to share or exchange, specify details like condition and genre, and manage their listings.

## Features

- Create book listings with detailed information (title, description, genre, condition)
- Withdraw listings when books are no longer available
- Browse available books by genre, condition, or owner
- Transparent ownership tracking

## Contract Functions

### Public Functions

- `create-listing`: List a book for exchange
- `withdraw-listing`: Remove a book from active listings
- `get-listing`: Retrieve details about a specific listing
- `get-owner`: Get the owner of a specific listing

### Constants

- Minimum quantity requirements
- Validation for book genres and conditions
- Error codes for various failure scenarios

## Data Structure

Each book listing contains:
- Owner information (principal)
- Book title (string)
- Description (string)
- Genre category
- Physical condition
- Availability status
- Quantity available

## Getting Started

To interact with the LitSwap protocol:

1. Deploy the contract to a Stacks blockchain node
2. Call the contract functions using a compatible wallet or Clarity development environment
3. Create listings for books you wish to exchange
4. Browse available listings from other users

## Future Development

- Implement direct book swapping functionality
- Add rating system for exchange participants
- Create notification system for new listings
- Expand genre and condition categories