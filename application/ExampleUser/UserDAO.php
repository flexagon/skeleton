<?php

namespace ExampleUser;

use _Flexagon\Base\BaseMySqlDAO;

/**
 * Example DAO.
 *
 * BaseMySqlDAO keeps its CRUD helpers protected on purpose: every DAO decides
 * for itself which operations to expose, so the public surface stays as narrow
 * as the domain actually needs.
 */
class UserDAO extends BaseMySqlDAO {
    protected string $tableName = 'users';

    /**
     * @param UserModel $user
     * @return int|false the auto_increment value, or false when the insert failed
     */
    public function insert(UserModel $user): int|false
    {
        return $this->_insert($user);
    }

    /**
     * @param UserModel $user
     * @return bool
     */
    public function update(UserModel $user): bool
    {
        return $this->_update($user);
    }

    /**
     * @param UserModel $user
     * @return bool
     */
    public function delete(UserModel $user): bool
    {
        return $this->_delete($user);
    }

    /**
     * @param int $id
     * @return UserModel|null
     */
    public function findById(int $id): ?UserModel
    {
        return $this->_select(['id' => $id], new UserModel());
    }

    /**
     * @param string $address
     * @param int $pageNumber
     * @param int $countPerPage
     * @return UserModel[]
     */
    public function findByAddress(string $address, int $pageNumber = 1, int $countPerPage = 20): array
    {
        return $this->_selectList(
            new UserModel(), $pageNumber, $countPerPage,
            '`address` = :ADDRESS', ['ADDRESS' => $address],
            '`id` DESC'
        );
    }

    /**
     * @param string $address
     * @return int
     */
    public function countByAddress(string $address): int
    {
        return $this->_selectTotalCount('`address` = :ADDRESS', ['ADDRESS' => $address]);
    }

    /**
     * Raw SQL stays available through $this->db.
     *
     * @return UserModel|null
     */
    public function selectLast(): ?UserModel
    {
        $query = sprintf('SELECT * FROM `%s` ORDER BY `id` DESC LIMIT 1', $this->tableName);
        $this->db->executeQuery($query);
        return $this->db->getResultAsObject(new UserModel);
    }

    /**
     * @return UserModel[]
     */
    public function selectList(): array
    {
        $query = sprintf("SELECT * FROM `%s`", $this->tableName);
        $this->db->executeQuery($query);
        return $this->db->getAllResultAsObject(new UserModel);
    }
}
