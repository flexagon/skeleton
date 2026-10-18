<?php

namespace I18n;

use _Flexagon\I18n\TranslatorInterface;
use Symfony\Contracts\Translation\TranslatorInterface as SymfonyTranslatorInterface;

class SymfonyTranslator implements TranslatorInterface
{
    public function __construct(
        private SymfonyTranslatorInterface $translator
    ) {
    }

    public function translate(string $message): string
    {
        return $this->translator->trans($message);
    }
}