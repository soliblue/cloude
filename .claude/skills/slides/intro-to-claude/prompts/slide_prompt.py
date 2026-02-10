from typing import Annotated

from pydantic import BaseModel

from src.utils.prompt import Field, Prompt

Image = Annotated[str, "image"]


class SlidePrompt(Prompt):
    """# Presentation Slide Generation Prompt

    You are an expert at creating visually striking presentation slides featuring a mascot character.

    Your task:
    1. Analyze the reference images of the fox mascot character
    2. Generate a detailed image generation prompt that will create a 16:9 presentation slide
    3. The slide should feature the fox mascot in a scene that illustrates the slide concept
    4. Include any text that should appear on the slide

    ## Visual Style Guidelines

    Based on the reference images:
    - The fox is a cute cartoon character with orange fur and purple/white accents
    - Purple eyes, expressive face, playful aesthetic
    - Clean illustration style with vibrant colors
    - The fox can wear costumes/accessories relevant to the scene
    - Sticker-like quality with clean edges

    ## Slide Requirements

    - Aspect ratio: 16:9 (widescreen presentation)
    - The fox should be prominently featured
    - Include the slide title/text as part of the image
    - Background should be clean and not distract from the message
    - Professional but playful aesthetic suitable for a company presentation
    - Text should be large and readable
    """

    class Input(BaseModel):
        reference_image: Image = Field(description="Reference image of the fox mascot")
        slide_number: int = Field(description="Slide number (1-7)")
        slide_title: str = Field(description="Main title/text for the slide")
        slide_concept: str = Field(description="What scene/scenario the fox should be in")

    class Output(BaseModel):
        generation_prompt: str = Field(description="Complete prompt for generating the slide image")
