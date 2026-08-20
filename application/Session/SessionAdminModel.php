<?php

namespace Session;


use _Flexagon\Base\BaseModel;

class SessionAdminModel extends BaseModel{
	private string $role = 'ADMIN';
	private ?string $username = '';
	private ?string $email = '';
	private ?string $realname = '';
	private $level;

    /**
     * @return string
     */
    public function getRole(): string
    {
        return $this->role;
    }

    /**
     * @param string $role
     */
    public function setRole(string $role): void
    {
        $this->role = $role;
    }

    /**
     * @return string|null
     */
	public function getUsername(): ?string
    {
		return $this->username;
	}

	/**
	 * @param ?string $username
	 */
	public function setUsername(?string $username): void
    {
		$this->username = $username;
	}

	/**
	 * @return ?string
	 */
	public function getEmail(): ?string
    {
		return $this->email;
	}

	/**
	 * @param ?string $email
	 */
	public function setEmail(?string $email): void
    {
		$this->email = $email;
	}

	/**
	 * @return ?string
	 */
	public function getRealname(): ?string
    {
		return $this->realname;
	}

	/**
	 * @param ?string $realname
	 */
	public function setRealname(?string $realname): void
    {
		$this->realname = $realname;
	}

	/**
	 * @return mixed
	 */
	public function getLevel() {
		return $this->level;
	}

	/**
	 * @param mixed $level
	 */
	public function setLevel($level): void
    {
		$this->level = $level;
	}

}