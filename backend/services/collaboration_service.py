import os
import asyncio

from agents.code_agent import code_agent
from agents.research_agent import research_agent
from agents.data_agent import data_agent


class CollaborationService:

    def __init__(self, client):
        self.client = client
        self.model = os.getenv("OPENAI_MODEL", "gpt-4.1-mini")

    async def collaborate(self, message, history=None):

        agents = [
            code_agent,
            research_agent,
            data_agent,
        ]

        context = [
            *list(history or []),
            {"role": "user", "content": message}
        ]

        async def run_agent(agent):
            response = await self.client.responses.create(
                model=self.model,
                instructions=agent.instructions,
                input=context
            )

            return {
                "agent": agent.name,
                "response": response.output_text
            }

        results = await asyncio.gather(
            *(run_agent(agent) for agent in agents)
        )

        combined = "\n\n".join(
            f"{result['agent']}:\n{result['response']}"
            for result in results
        )

        final_response = await self.client.responses.create(
            model=self.model,
            instructions=(
                "You are OMEGA Core. Combine the specialist "
                "analyses into one accurate, coherent answer. "
                "Resolve contradictions and acknowledge uncertainty. "
                "Respond in the user's language."
            ),
            input=(
                f"Original request:\n{message}\n\n"
                f"Specialist analyses:\n{combined}"
            )
        )

        return {
            "response": final_response.output_text,
            "agent": "OMEGA Collaboration",
            "agent_key": "collaboration",
            "collaborators": [agent.name for agent in agents]
        }