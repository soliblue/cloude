package com.cloude.app.Models

data class SlashCommand(
    val name: String,
    val description: String,
    val isSkill: Boolean,
    val resolvesTo: String? = null,
    val hasParameters: Boolean = false
) {
    companion object {
        val builtIn = listOf(
            SlashCommand("compact", "Compact conversation context", false),
            SlashCommand("context", "Show context window usage", false),
            SlashCommand("cost", "Show session cost", false)
        )

        fun fromSkills(skills: List<Skill>): List<SlashCommand> {
            val commands = mutableListOf<SlashCommand>()
            skills.filter { it.userInvocable }.forEach { skill ->
                commands.add(
                    SlashCommand(
                        name = skill.name,
                        description = skill.description ?: "",
                        isSkill = true,
                        hasParameters = skill.parameters.isNotEmpty()
                    )
                )
                skill.aliases.forEach { alias ->
                    commands.add(
                        SlashCommand(
                            name = alias,
                            description = skill.description ?: "",
                            isSkill = true,
                            resolvesTo = skill.name,
                            hasParameters = skill.parameters.isNotEmpty()
                        )
                    )
                }
            }
            return commands
        }

        fun allCommands(skills: List<Skill>): List<SlashCommand> =
            builtIn + fromSkills(skills)

        fun filtered(query: String, skills: List<Skill>): List<SlashCommand> {
            val all = allCommands(skills)
            if (query.isEmpty()) return all.filter { it.resolvesTo == null }
            val lower = query.lowercase()
            val exact = all.firstOrNull { it.name.lowercase() == lower }
            if (exact != null) return listOf(exact)
            return all.filter { it.name.lowercase().startsWith(lower) }
        }
    }
}
