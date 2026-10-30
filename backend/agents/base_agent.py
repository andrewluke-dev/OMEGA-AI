from dataclasses import dataclass


@dataclass(frozen=True)
class Agent:
    name: str
    instructions: str