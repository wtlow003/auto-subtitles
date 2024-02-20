from typing import Tuple, Union

import srt
from transformers import (
    AutoModelForSeq2SeqLM,
    AutoTokenizer,
    PreTrainedModel,
    PreTrainedTokenizer,
    PreTrainedTokenizerFast,
    pipeline,
)

import cli
from constants import TRANSLATION_MODELS_DICT


class TranslationModel:
    def __init__(self, source_lang: str, target_lang: str, model_name: str):
        self.source_lang = source_lang
        self.target_lang = target_lang
        self.model = self.__load_model(model_name)

    @classmethod
    def __load_model(
        cls, model_name: str
    ) -> Tuple[PreTrainedModel, Union[PreTrainedTokenizer, PreTrainedTokenizerFast]]:
        """_summary_

        Args:
            model_name (str): _description_

        Returns:
            Tuple[PreTrainedModel, Union[PreTrainedTokenizer, PreTrainedTokenizerFast]]: _description_
        """
        model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
        tokenizer: Union[
            PreTrainedTokenizer, PreTrainedTokenizerFast
        ] = AutoTokenizer.from_pretrained(model_name)

        return (model, tokenizer)

    def translate(self, text: str):
        """_summary_

        Args:
            text (str): _description_

        Returns:
            _type_: _description_
        """
        translator = pipeline(
            task="translation",
            model=self.model[0],
            tokenizer=self.model[1],
            src_lang=self.source_lang,
            tgt_lang=self.target_lang,
        )
        output = translator(text)  # type: ignore

        output: list = output[0]["translation_text"]
        result = {
            "source": self.source_lang,
            "target": self.target_lang,
            "result": output,
        }

        return result


def main():
    args = cli.translator_cli()
    model = TranslationModel(
        source_lang=args.translate_from,
        target_lang=args.translate_to,
        model_name=TRANSLATION_MODELS_DICT["nllb-distilled-600M"],
    )

    with open(args.subs_path) as f:
        subs = list(srt.parse(f.read()))

    for sub in subs:
        sub.content = model.translate(sub.content)["result"]

    with open(args.subs_path, "w") as f:
        f.write(srt.compose(subs))


if __name__ == "__main__":
    main()
