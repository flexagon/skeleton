<?php
namespace I18n;

use _Flexagon\I18n\TranslatorInterface;

class GettextTranslator implements TranslatorInterface
{
    public function translate(string $message): string
    {
        return gettext($message);
    }
}