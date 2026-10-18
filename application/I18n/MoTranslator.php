<?php

namespace I18n;

use _Flexagon\I18n\TranslatorInterface;

class MoTranslator implements TranslatorInterface
{
    public function translate(string $message): string
    {
        return __($message);
    }
}